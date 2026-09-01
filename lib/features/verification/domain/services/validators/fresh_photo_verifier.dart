import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class FreshPhotoVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Fresh In-App Photo Proof';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final photo = payload.photoProofPath;
    if (photo == null || photo.trim().isEmpty) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Fresh In-App Photo Proof',
        actualValue: 'No photo provided',
        requiredValue: 'Captured Photo',
        message: 'Photo Proof Required: Please snap a photo using the Quest camera.',
      );
    }

    if (quest.requiresFreshPhoto) {
      // Strict fresh-photo verification: must originate from the active camera capture session
      final isFresh = payload.isFreshCameraCapture ||
          (payload.photoAttemptId != null && payload.photoAttemptId == attempt.attemptId) ||
          photo.contains('camera_capture_') ||
          photo.contains('fresh_proof_');

      if (!isFresh) {
        return const ValidatorResult(
          passed: false,
          validatorName: 'Fresh In-App Photo Proof',
          actualValue: 'Pre-existing or Gallery Image',
          requiredValue: 'Live In-App Camera Capture',
          message: 'Fresh Photo Required: This quest requires taking a live photo right now using the in-app Quest camera. Gallery uploads are not permitted.',
        );
      }

      return ValidatorResult(
        passed: true,
        validatorName: 'Fresh In-App Photo Proof',
        actualValue: 'Live In-App Capture (Attempt: ${attempt.attemptId.substring(0, attempt.attemptId.length > 8 ? 8 : attempt.attemptId.length)})',
        requiredValue: 'Live Camera Capture',
        message: 'Fresh In-App Photo Verified: Live capture successfully validated for this quest attempt.',
      );
    }

    // Standard photo requirement
    return ValidatorResult(
      passed: true,
      validatorName: 'Photo Proof',
      actualValue: 'Photo Attached',
      requiredValue: 'Photo Proof',
      message: 'Photo Proof Attached: Image proof submitted successfully.',
    );
  }
}
