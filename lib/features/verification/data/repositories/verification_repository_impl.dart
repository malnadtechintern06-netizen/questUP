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

import 'package:quest_up/features/verification/data/datasources/quest_verification_api_client.dart';
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
  final IQuestVerificationApiClient apiClient;
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
    IQuestVerificationApiClient? apiClient,
  })  : duplicateProofService = duplicateProofService ?? DuplicateProofService(localDataSource),
        mySqlDataSource = mySqlDataSource ?? QuestMySqlDataSource(),
        apiClient = apiClient ?? QuestVerificationApiClient.instance,
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
    dev.log('[PROOF] Server-authoritative verification started for quest: "${quest.title}" (${quest.id})', name: 'SmartProof');

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

    // 2. Start server-authoritative verification attempt challenge
    final startRes = await apiClient.startVerification(
      questId: quest.id,
      userId: profile.id,
    );

    if (!startRes.success && startRes.isDuplicate) {
      return VerificationResult(
        isSuccessful: false,
        message: startRes.message,
        isGpsValid: true,
        isCameraValid: true,
      );
    }

    final serverAttemptId = startRes.attemptId.isNotEmpty
        ? startRes.attemptId
        : (session?.sessionId ?? _uuid.v4());
    final challengeToken = startRes.challengeToken;

    final effectiveAttempt = attempt ??
        QuestAttempt(
          attemptId: serverAttemptId,
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
          sessionId: session?.sessionId ?? serverAttemptId,
          questSession: session,
          mediaHash: computedHash,
          videoProofPath: videoProofPath,
          drawingProofSummary: drawingProofSummary,
          textContent: textContent,
          wordCount: wordCount,
          durationSeconds: durationSeconds,
          distanceMeters: distanceMeters,
        );

    // 3. If photo proof present, upload photo to server for SHA-256 and GD dHash inspection
    PhotoProofUploadResponse? uploadRes;
    final photoPathToUpload = effectivePayload.photoProofPath ?? photoProofPath;
    if (photoPathToUpload != null && photoPathToUpload.isNotEmpty) {
      uploadRes = await apiClient.uploadPhotoProof(
        attemptId: serverAttemptId,
        userId: profile.id,
        photoFilePath: photoPathToUpload,
        clientCaptureTime: effectivePayload.capturedAt ?? DateTime.now(),
      );

      if (!uploadRes.success) {
        dev.log('[PROOF] Server photo proof upload/analysis rejected: ${uploadRes.message}', name: 'SmartProof');
        return VerificationResult(
          isSuccessful: false,
          message: uploadRes.message,
          isGpsValid: userLat != null || effectivePayload.userLat != null,
          isCameraValid: false,
        );
      }
      if (uploadRes.imageHash.isNotEmpty) {
        computedHash = uploadRes.imageHash;
      }
    }

    // 4. Centralized Smart Proof Verification Engine Evaluation (local telemetry check)
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
        sessionId: serverAttemptId,
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

      dev.log('[PROOF] Proof submission REJECTED locally: ${report.overallMessage}', name: 'SmartProof');

      return VerificationResult(
        isSuccessful: false,
        message: report.overallMessage,
        isGpsValid: userLat != null || effectivePayload.userLat != null,
        isCameraValid: photoProofPath != null || effectivePayload.photoProofPath != null,
        validatorResults: report.results,
      );
    }

    // 5. Authoritative Backend Final Verification
    ServerVerificationResult? serverVerification;
    if (challengeToken.isNotEmpty) {
      serverVerification = await apiClient.verifyQuest(
        attemptId: serverAttemptId,
        challengeToken: challengeToken,
        questId: quest.id,
        userId: profile.id,
        latitude: effectivePayload.userLat ?? userLat,
        longitude: effectivePayload.userLon ?? userLon,
        proofPayload: {
          'photo_path': photoProofPath ?? effectivePayload.photoProofPath,
          'image_hash': uploadRes?.imageHash ?? computedHash,
          'perceptual_hash': uploadRes?.perceptualHash,
          'is_camera_capture': effectivePayload.isFreshCameraCapture,
          'duration_seconds': effectivePayload.durationSeconds ?? durationSeconds ?? 0,
          'distance_meters': effectivePayload.distanceMeters ?? distanceMeters ?? 0.0,
          'text_content': effectivePayload.textContent ?? textContent,
          'word_count': effectivePayload.wordCount ?? wordCount ?? 0,
          'drawing_summary': effectivePayload.drawingProofSummary ?? drawingProofSummary,
          'secret_code': effectivePayload.secretCode,
          'quiz_answers': effectivePayload.quizAnswers,
          'qr_code_data': effectivePayload.qrCodeData,
          'task_confirmed': effectivePayload.taskConfirmed,
        },
      );

      if (!serverVerification.success) {
        dev.log('[PROOF] Authoritative Server REJECTED verification: ${serverVerification.message}', name: 'SmartProof');
        return VerificationResult(
          isSuccessful: false,
          message: serverVerification.message,
          isGpsValid: userLat != null || effectivePayload.userLat != null,
          isCameraValid: photoProofPath != null || effectivePayload.photoProofPath != null,
          validatorResults: report.results,
        );
      }

      // 6. Handle Pending Admin Review Flow
      if (serverVerification.isPendingAdminReview || serverVerification.status == 'pending_admin' || serverVerification.status == 'pending') {
        dev.log('[PROOF] Quest submitted for admin review: attemptId=$serverAttemptId', name: 'SmartProof');
        return VerificationResult(
          isSuccessful: true,
          isPendingAdminReview: true,
          message: serverVerification.message,
          isGpsValid: true,
          isCameraValid: true,
          validatorResults: report.results,
        );
      }
    }

    final authoritativeXp = (serverVerification != null && serverVerification.xpEarned > 0)
        ? serverVerification.xpEarned
        : quest.xpReward;
    final authoritativeCoins = (serverVerification != null && serverVerification.coinsEarned > 0)
        ? serverVerification.coinsEarned
        : quest.coinReward;
    final successMessage = serverVerification?.message ?? report.overallMessage;

    // 7. Authoritative Verified Flow: Mark Quest as Completed
    await questRepository.markQuestCompleted(quest.id);

    // Update Quest Session to Verified
    if (session != null) {
      final updatedSession = session.copyWith(
        status: QuestSessionStatus.verified,
        completedAt: DateTime.now(),
      );
      await localDataSource.updateQuestSession(updatedSession);
    }

    // Save Verified Quest Proof record (with SHA-256 fingerprint)
    final verifiedProof = QuestProof(
      proofId: _uuid.v4(),
      sessionId: serverAttemptId,
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
      verificationReason: successMessage,
      contentVerificationStatus: 'pass',
      createdAt: DateTime.now(),
    );
    await localDataSource.saveProof(verifiedProof);

    // 8. Update User Profile with Server's Authoritative XP & Coins
    final profileBefore = await userRepository.getUserProfile();
    final updatedProfile = await userRepository.addXpAndCoins(
      xp: authoritativeXp,
      coins: authoritativeCoins,
      completedQuestId: quest.id,
    );

    final didLevelUp = (serverVerification != null && serverVerification.didLevelUp) ||
        (updatedProfile.level > profileBefore.level);
    final finalLevel = (serverVerification != null && serverVerification.newLevel > 0)
        ? serverVerification.newLevel
        : updatedProfile.level;

    dev.log('[PROOF] Server-authoritative reward granted: +$authoritativeXp XP, +$authoritativeCoins Coins. New Level: $finalLevel', name: 'SmartProof');

    // 9. Create & Save Completion Record
    final finalProof = effectivePayload.photoProofPath ??
        effectivePayload.drawingProofSummary ??
        effectivePayload.videoProofPath ??
        'smart_proof_verified';

    final completionId = (serverVerification != null && serverVerification.completionId.isNotEmpty)
        ? serverVerification.completionId
        : _uuid.v4();

    final completion = QuestCompletionModel(
      id: completionId,
      questId: quest.id,
      userId: updatedProfile.id,
      completedAt: DateTime.now(),
      userLatitude: effectivePayload.userLat ?? userLat ?? 0.0,
      userLongitude: effectivePayload.userLon ?? userLon ?? 0.0,
      photoProofPath: finalProof,
      status: VerificationStatus.verified,
      xpEarned: authoritativeXp,
      coinsEarned: authoritativeCoins,
    );
    await localDataSource.saveCompletion(completion);

    // 10. Record Success into Quest Calendar
    if (calendarRepository != null) {
      try {
        await calendarRepository!.recordQuestActivity(
          questId: quest.id,
          questTitle: quest.title,
          category: quest.category.name,
          difficulty: quest.difficulty.name,
          status: QuestActivityStatus.completed,
          xpReward: authoritativeXp,
          coinReward: authoritativeCoins,
        );
      } catch (_) {}
    }

    // 11. Check Badge / Achievements Unlocks
    final unlockedBadge = await achievementRepository.evaluateAndUnlockAchievements(
      completedCount: updatedProfile.completedQuestIds.length,
      currentLevel: finalLevel,
      totalCoins: updatedProfile.coins,
    );

    return VerificationResult(
      isSuccessful: true,
      message: successMessage,
      isGpsValid: true,
      isCameraValid: true,
      completion: completion,
      xpEarned: authoritativeXp,
      coinsEarned: authoritativeCoins,
      didLevelUp: didLevelUp,
      newLevel: finalLevel,
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
