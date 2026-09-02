import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

class VerifyQuestUseCase {
  final VerificationRepository _repository;

  const VerifyQuestUseCase(this._repository);

  Future<VerificationResult> call({
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
    return await _repository.verifyAndCompleteQuest(
      quest: quest,
      attempt: attempt,
      payload: payload,
      sessionId: sessionId,
      userLat: userLat,
      userLon: userLon,
      photoProofPath: photoProofPath,
      videoProofPath: videoProofPath,
      drawingProofSummary: drawingProofSummary,
      textContent: textContent,
      wordCount: wordCount,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      mediaHash: mediaHash,
    );
  }
}
