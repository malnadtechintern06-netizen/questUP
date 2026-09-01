import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

abstract class VerificationRepository {
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
  });

  Future<List<QuestCompletion>> getCompletionsForUser(String userId);
}
