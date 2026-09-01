import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';

class VerificationProofPayload {
  final double? userLat;
  final double? userLon;
  final String? photoProofPath;
  final bool isFreshCameraCapture;
  final String? photoAttemptId;
  final String? videoProofPath;
  final int? durationSeconds;
  final String? textContent;
  final int? wordCount;
  final int? lineCount;
  final String? drawingProofSummary;
  final int? strokeCount;
  final double? distanceMeters;
  final int? gameplaySeconds;
  final int? repetitionCount;

  const VerificationProofPayload({
    this.userLat,
    this.userLon,
    this.photoProofPath,
    this.isFreshCameraCapture = false,
    this.photoAttemptId,
    this.videoProofPath,
    this.durationSeconds,
    this.textContent,
    this.wordCount,
    this.lineCount,
    this.drawingProofSummary,
    this.strokeCount,
    this.distanceMeters,
    this.gameplaySeconds,
    this.repetitionCount,
  });
}

abstract class IQuestValidator {
  String get validatorName;

  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  });
}
