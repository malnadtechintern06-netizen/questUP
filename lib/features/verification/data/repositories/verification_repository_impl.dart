import 'package:uuid/uuid.dart';
import 'package:quest_up/features/achievements/domain/repositories/achievement_repository.dart';
import 'package:quest_up/features/profile/domain/repositories/user_repository.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/domain/repositories/quest_repository.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';
import 'package:quest_up/features/verification/data/models/quest_completion_model.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';
import 'package:quest_up/features/verification/domain/services/quest_verification_service.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  final IVerificationLocalDataSource localDataSource;
  final QuestRepository questRepository;
  final UserRepository userRepository;
  final AchievementRepository achievementRepository;
  final IQuestVerificationService verificationService;
  final Uuid _uuid = const Uuid();

  VerificationRepositoryImpl({
    required this.localDataSource,
    required this.questRepository,
    required this.userRepository,
    required this.achievementRepository,
    IQuestVerificationService? verificationService,
  }) : verificationService = verificationService ?? QuestVerificationService();

  @override
  Future<VerificationResult> verifyAndCompleteQuest({
    required Quest quest,
    QuestAttempt? attempt,
    VerificationProofPayload? payload,
    double? userLat,
    double? userLon,
    String? photoProofPath,
    String? videoProofPath,
    String? drawingProofSummary,
    String? textContent,
    int? wordCount,
    int? durationSeconds,
    double? distanceMeters,
  }) async {
    final effectiveAttempt = attempt ??
        QuestAttempt(
          attemptId: _uuid.v4(),
          userId: 'player',
          questId: quest.id,
          startedAt: DateTime.now(),
        );

    final effectivePayload = payload ??
        VerificationProofPayload(
          userLat: userLat,
          userLon: userLon,
          photoProofPath: photoProofPath,
          isFreshCameraCapture: photoProofPath != null && photoProofPath.isNotEmpty,
          videoProofPath: videoProofPath,
          drawingProofSummary: drawingProofSummary,
          textContent: textContent,
          wordCount: wordCount,
          durationSeconds: durationSeconds,
          distanceMeters: distanceMeters,
        );

    // 1. Centralized Universal Engine Evaluation
    final report = await verificationService.evaluateAttempt(
      quest: quest,
      attempt: effectiveAttempt,
      payload: effectivePayload,
    );

    if (!report.isSuccessful) {
      return VerificationResult(
        isSuccessful: false,
        message: report.overallMessage,
        isGpsValid: userLat != null || effectivePayload.userLat != null,
        isCameraValid: photoProofPath != null || effectivePayload.photoProofPath != null,
        validatorResults: report.results,
      );
    }

    // 2. Mark Quest as Completed
    await questRepository.markQuestCompleted(quest.id);

    // 3. Update User Profile (XP & Coins)
    final profileBefore = await userRepository.getUserProfile();
    final updatedProfile = await userRepository.addXpAndCoins(
      xp: quest.xpReward,
      coins: quest.coinReward,
      completedQuestId: quest.id,
    );

    final didLevelUp = updatedProfile.level > profileBefore.level;

    // 4. Create & Save Completion Record
    final finalProof = effectivePayload.photoProofPath ??
        effectivePayload.drawingProofSummary ??
        effectivePayload.videoProofPath ??
        'text_verified';

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

    // 5. Check Badge / Achievements Unlocks
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
}
