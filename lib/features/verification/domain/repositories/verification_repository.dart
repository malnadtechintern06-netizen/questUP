import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/entities/quest_proof.dart';
import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

abstract class VerificationRepository {
  Future<QuestSession> startQuestSession({
    required String questId,
    required String userId,
    double? startingLat,
    double? startingLon,
    String? requiredProofType,
  });

  Future<QuestSession?> getActiveQuestSession({
    required String questId,
    required String userId,
  });

  Future<void> cancelQuestSession(String sessionId);

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
  });

  Future<List<QuestCompletion>> getCompletionsForUser(String userId);
  Future<List<QuestProof>> getProofsForQuest(String questId);
}
