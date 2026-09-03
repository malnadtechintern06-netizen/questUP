import 'dart:developer' as dev;
import 'package:uuid/uuid.dart';
import 'package:quest_up/features/achievements/domain/repositories/achievement_repository.dart';
import 'package:quest_up/features/calendar/domain/entities/quest_calendar_entry.dart';
import 'package:quest_up/features/calendar/domain/repositories/quest_calendar_repository.dart';
import 'package:quest_up/features/profile/domain/repositories/user_repository.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/domain/repositories/quest_repository.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';
import 'package:quest_up/features/verification/data/models/quest_completion_model.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/entities/quest_proof.dart';
import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';
import 'package:quest_up/features/verification/domain/services/duplicate_proof_service.dart';
import 'package:quest_up/features/verification/domain/services/quest_verification_service.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  final IVerificationLocalDataSource localDataSource;
  final QuestRepository questRepository;
  final UserRepository userRepository;
  final AchievementRepository achievementRepository;
  final QuestCalendarRepository? calendarRepository;
  final IQuestVerificationService verificationService;
  final IDuplicateProofService duplicateProofService;
  final IQuestMySqlDataSource mySqlDataSource;
  final Uuid _uuid = const Uuid();

  VerificationRepositoryImpl({
    required this.localDataSource,
    required this.questRepository,
    required this.userRepository,
    required this.achievementRepository,
    this.calendarRepository,
    IDuplicateProofService? duplicateProofService,
    IQuestVerificationService? verificationService,
    IQuestMySqlDataSource? mySqlDataSource,
  })  : duplicateProofService = duplicateProofService ?? DuplicateProofService(localDataSource),
        mySqlDataSource = mySqlDataSource ?? QuestMySqlDataSource(),
        verificationService = verificationService ??
            QuestVerificationService(
              duplicateProofService: duplicateProofService ?? DuplicateProofService(localDataSource),
            );

  @override
  Future<QuestSession> startQuestSession({
    required String questId,
    required String userId,
    double? startingLat,
    double? startingLon,
    String? requiredProofType,
  }) async {
    final now = DateTime.now();
    final session = QuestSession(
      sessionId: _uuid.v4(),
      userId: userId,
      questId: questId,
      startedAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      startingLocationLat: startingLat,
      startingLocationLon: startingLon,
      status: QuestSessionStatus.inProgress,
      requiredProofType: requiredProofType,
    );

    await localDataSource.saveQuestSession(session);
    dev.log('[PROOF] Quest session created: sessionId=${session.sessionId} for quest=$questId', name: 'SmartProof');
    return session;
  }

  @override
  Future<QuestSession?> getActiveQuestSession({
    required String questId,
    required String userId,
  }) async {
    return localDataSource.getActiveSessionForQuest(questId, userId);
  }

  @override
  Future<void> cancelQuestSession(String sessionId) async {
    final session = await localDataSource.getQuestSession(sessionId);
    if (session != null) {
      final updated = session.copyWith(status: QuestSessionStatus.rejected);
      await localDataSource.updateQuestSession(updated);
    }
  }

  @override
  Future<VerificationResult> verifyAndCompleteQuest({
    required Quest quest,
    QuestAttempt? attempt,
    VerificationProofPayload? payload,
    String? sessionId,
    double? userLat,
    double? userLon,
    String? photoProofPath,
    String? videoProofPath,
    String? drawingProofSummary,
    String? textContent,
    int? wordCount,
    int? durationSeconds,
    double? distanceMeters,
    String? mediaHash,
  }) async {
    dev.log('[PROOF] Proof submission started for quest: "${quest.title}" (${quest.id})', name: 'SmartProof');

    // 0. Double-reward prevention check
    final profile = await userRepository.getUserProfile();
    if (profile.completedQuestIds.contains(quest.id)) {
      dev.log('[PROOF] Repeated completion blocked: quest "${quest.id}" already completed by user "${profile.id}"', name: 'SmartProof');
      return const VerificationResult(
        isSuccessful: false,
        message: 'Quest already completed! Rewards have already been claimed.',
        isGpsValid: true,
        isCameraValid: true,
      );
    }

    // 1. Resolve or Validate Quest Session
    QuestSession? session;
    if (sessionId != null && sessionId.isNotEmpty) {
      session = await localDataSource.getQuestSession(sessionId);
    } else {
      session = await localDataSource.getActiveSessionForQuest(quest.id, profile.id);
    }

    final effectiveAttempt = attempt ??
        QuestAttempt(
          attemptId: session?.sessionId ?? _uuid.v4(),
          userId: profile.id,
          questId: quest.id,
          startedAt: session?.startedAt ?? DateTime.now(),
        );

    // Compute media hash if not pre-supplied
    String? computedHash = mediaHash;
    if (computedHash == null || computedHash.isEmpty) {
      if (photoProofPath != null && photoProofPath.isNotEmpty) {
        computedHash = await duplicateProofService.computeFileHash(photoProofPath);
      } else if (videoProofPath != null && videoProofPath.isNotEmpty) {
        computedHash = await duplicateProofService.computeFileHash(videoProofPath);
      } else if (drawingProofSummary != null && drawingProofSummary.isNotEmpty) {
        computedHash = duplicateProofService.computeContentHash(drawingProofSummary);
      } else if (textContent != null && textContent.isNotEmpty) {
        computedHash = duplicateProofService.computeContentHash(textContent);
      }
    }

    final effectivePayload = payload ??
        VerificationProofPayload(
          userLat: userLat,
          userLon: userLon,
          photoProofPath: photoProofPath,
          isFreshCameraCapture: photoProofPath != null && photoProofPath.isNotEmpty,
          sessionId: session?.sessionId,
          questSession: session,
          mediaHash: computedHash,
          videoProofPath: videoProofPath,
          drawingProofSummary: drawingProofSummary,
          textContent: textContent,
          wordCount: wordCount,
          durationSeconds: durationSeconds,
          distanceMeters: distanceMeters,
        );

    // 2. Centralized Smart Proof Verification Engine Evaluation
    final report = await verificationService.evaluateAttempt(
      quest: quest,
      attempt: effectiveAttempt,
      payload: effectivePayload,
    );

    if (!report.isSuccessful) {
      // Record failure into Quest Calendar
      if (calendarRepository != null) {
        try {
          await calendarRepository!.recordQuestActivity(
            questId: quest.id,
            questTitle: quest.title,
            category: quest.category.name,
            difficulty: quest.difficulty.name,
            status: QuestActivityStatus.failed,
            failureReason: report.overallMessage,
            xpReward: quest.xpReward,
            coinReward: quest.coinReward,
          );
        } catch (_) {}
      }

      // Record rejected proof
      final rejectedProof = QuestProof(
        proofId: _uuid.v4(),
        sessionId: session?.sessionId ?? effectiveAttempt.attemptId,
        questId: quest.id,
        userId: profile.id,
        proofType: quest.verificationType.name,
        capturedAt: DateTime.now(),
        submittedAt: DateTime.now(),
        latitude: effectivePayload.userLat ?? userLat,
        longitude: effectivePayload.userLon ?? userLon,
        mediaReference: photoProofPath ?? videoProofPath ?? drawingProofSummary ?? textContent,
        mediaHash: computedHash,
        isFreshCameraCapture: effectivePayload.isFreshCameraCapture,
        screenDetection: report.results.any((r) => r.validatorName.contains('Screen') && !r.passed && ((r.actualValue?.contains('Screen') ?? false) || (r.actualValue?.contains('Display') ?? false))),
        isPhotoOfPhoto: report.results.any((r) => r.validatorName.contains('Screen') && !r.passed && ((r.actualValue?.contains('Printed') ?? false) || (r.actualValue?.contains('Poster') ?? false) || (r.actualValue?.contains('Photo') ?? false))),
        sceneContextStatus: report.results.any((r) => r.validatorName.contains('Scene') && !r.passed) ? 'insufficient_context' : 'authentic',
        verificationStatus: ProofVerificationStatus.rejected,
        verificationReason: report.overallMessage,
        createdAt: DateTime.now(),
      );
      await localDataSource.saveProof(rejectedProof);

      dev.log('[PROOF] Proof submission REJECTED: ${report.overallMessage}', name: 'SmartProof');

      return VerificationResult(
        isSuccessful: false,
        message: report.overallMessage,
        isGpsValid: userLat != null || effectivePayload.userLat != null,
        isCameraValid: photoProofPath != null || effectivePayload.photoProofPath != null,
        validatorResults: report.results,
      );
    }

    // 3. Mark Quest as Completed
    await questRepository.markQuestCompleted(quest.id);

    // 4. Update Quest Session to Verified
    if (session != null) {
      final updatedSession = session.copyWith(
        status: QuestSessionStatus.verified,
        completedAt: DateTime.now(),
      );
      await localDataSource.updateQuestSession(updatedSession);
    }

    // 5. Save Verified Quest Proof record (with SHA-256 fingerprint)
    final verifiedProof = QuestProof(
      proofId: _uuid.v4(),
      sessionId: session?.sessionId ?? effectiveAttempt.attemptId,
      questId: quest.id,
      userId: profile.id,
      proofType: quest.verificationType.name,
      capturedAt: DateTime.now(),
      submittedAt: DateTime.now(),
      latitude: effectivePayload.userLat ?? userLat,
      longitude: effectivePayload.userLon ?? userLon,
      mediaReference: photoProofPath ?? videoProofPath ?? drawingProofSummary ?? textContent,
      mediaHash: computedHash,
      isFreshCameraCapture: effectivePayload.isFreshCameraCapture,
      screenDetection: false,
      isPhotoOfPhoto: false,
      sceneContextStatus: 'authentic',
      verificationStatus: ProofVerificationStatus.verified,
      verificationReason: report.overallMessage,
      contentVerificationStatus: 'pass',
      createdAt: DateTime.now(),
    );
    await localDataSource.saveProof(verifiedProof);

    // 6. Update User Profile (XP & Coins Granted ATOMICALLY)
    final profileBefore = await userRepository.getUserProfile();
    final updatedProfile = await userRepository.addXpAndCoins(
      xp: quest.xpReward,
      coins: quest.coinReward,
      completedQuestId: quest.id,
    );

    final didLevelUp = updatedProfile.level > profileBefore.level;
    dev.log('[PROOF] Reward granted: +${quest.xpReward} XP, +${quest.coinReward} Coins. Total XP: ${updatedProfile.currentXp}', name: 'SmartProof');

    // 7. Create & Save Completion Record
    final finalProof = effectivePayload.photoProofPath ??
        effectivePayload.drawingProofSummary ??
        effectivePayload.videoProofPath ??
        'smart_proof_verified';

    final completion = QuestCompletionModel(
      id: _uuid.v4(),
      questId: quest.id,
      userId: updatedProfile.id,
      completedAt: DateTime.now(),
      userLatitude: effectivePayload.userLat ?? userLat ?? 0.0,
      userLongitude: effectivePayload.userLon ?? userLon ?? 0.0,
      photoProofPath: finalProof,
      status: VerificationStatus.verified,
      xpEarned: quest.xpReward,
      coinsEarned: quest.coinReward,
    );
    await localDataSource.saveCompletion(completion);

    // Save completion to MySQL database
    try {
      await mySqlDataSource.saveCompletionToMySql(completion);
    } catch (e) {
      dev.log('[PROOF] MySQL completion save notice: $e', name: 'SmartProof');
    }

    // 8. Record Success into Quest Calendar
    if (calendarRepository != null) {
      try {
        await calendarRepository!.recordQuestActivity(
          questId: quest.id,
          questTitle: quest.title,
          category: quest.category.name,
          difficulty: quest.difficulty.name,
          status: QuestActivityStatus.completed,
          xpReward: quest.xpReward,
          coinReward: quest.coinReward,
        );
      } catch (_) {}
    }

    // 9. Check Badge / Achievements Unlocks
    final unlockedBadge = await achievementRepository.evaluateAndUnlockAchievements(
      completedCount: updatedProfile.completedQuestIds.length,
      currentLevel: updatedProfile.level,
      totalCoins: updatedProfile.coins,
    );

    return VerificationResult(
      isSuccessful: true,
      message: report.overallMessage,
      isGpsValid: true,
      isCameraValid: true,
      completion: completion,
      xpEarned: quest.xpReward,
      coinsEarned: quest.coinReward,
      didLevelUp: didLevelUp,
      newLevel: updatedProfile.level,
      unlockedBadgeTitle: unlockedBadge?.title,
      validatorResults: report.results,
    );
  }

  @override
  Future<List<QuestCompletion>> getCompletionsForUser(String userId) async {
    final all = await localDataSource.getCompletions();
    return all.where((c) => c.userId == userId).toList();
  }

  @override
  Future<List<QuestProof>> getProofsForQuest(String questId) async {
    return localDataSource.getProofsForQuest(questId);
  }
}
