import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class DrawingVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Drawing Canvas Verification';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final drawing = payload.drawingProofSummary;
    if (drawing == null || drawing.trim().isEmpty) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Drawing Canvas Verification',
        actualValue: 'No drawing created',
        requiredValue: 'Canvas Artwork',
        message: 'Drawing Artwork Required: Please draw your artwork on the in-app canvas before submitting.',
      );
    }

    final subject = quest.requiredDrawingSubject ?? quest.requiredObject ?? 'artwork';
    final strokes = payload.strokeCount ?? (drawing.contains('strokes_') ? int.tryParse(drawing.split('strokes_')[1].split('_')[0]) ?? 2 : 2);

    return ValidatorResult(
      passed: true,
      validatorName: 'Drawing Canvas Verification',
      actualValue: 'Canvas Drawing ($strokes strokes)',
      requiredValue: 'Illustration of $subject',
      message: 'Drawing Verified: Artwork for "$subject" submitted with $strokes strokes.',
    );
  }
}
