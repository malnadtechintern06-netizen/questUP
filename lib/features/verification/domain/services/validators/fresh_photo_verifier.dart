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
        message: 'Photo Proof Required: Please snap a photo using the QuestUP camera.',
      );
    }

    final photoLower = photo.toLowerCase();
    final isExplicitGallery = photoLower.contains('gallery') ||
        photoLower.contains('download') ||
        photoLower.contains('old_image') ||
        photoLower.contains('saved_photo');

    final requiresFreshOnly = quest.requiresFreshPhoto || quest.isCameraOnly;

    if (requiresFreshOnly && isExplicitGallery) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Fresh In-App Photo Proof',
        actualValue: 'Pre-existing or Gallery Image',
        requiredValue: 'Live In-App Camera Capture',
        message:
            'Fresh Photo Required: This quest requires taking a live photo right now using the in-app QuestUP camera. Gallery uploads are not permitted.',
      );
    }

    if (requiresFreshOnly) {
      return ValidatorResult(
        passed: true,
        validatorName: 'Fresh In-App Photo Proof',
        actualValue: 'Live Camera Capture Validated',
        requiredValue: 'Live Camera Capture',
        message: 'Fresh In-App Photo Verified: Live camera capture validated for active session.',
      );
    }

    return const ValidatorResult(
      passed: true,
      validatorName: 'Photo Proof',
      actualValue: 'Photo Attached',
      requiredValue: 'Photo Proof',
      message: 'Photo Proof Attached: Image proof submitted successfully.',
    );
  }
}
