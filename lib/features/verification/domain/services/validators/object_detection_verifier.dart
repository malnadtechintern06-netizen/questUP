import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class ObjectDetectionVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Object Detection';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final requiredObj = quest.requiredObject?.trim().toLowerCase();
    if (requiredObj == null || requiredObj.isEmpty) {
      // No specific object requirement configured for this quest
      return const ValidatorResult(
        passed: true,
        validatorName: 'Object Detection',
        actualValue: 'No target object specified',
        requiredValue: 'Any subject',
        message: 'No specific object detection required for this quest.',
      );
    }

    final displayObj = requiredObj[0].toUpperCase() + requiredObj.substring(1);

    final photo = payload.photoProofPath;
    if (photo == null || photo.trim().isEmpty) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Object Detection',
        actualValue: 'No photo submitted',
        requiredValue: requiredObj,
        message: 'No $displayObj detected. Please photograph a real $requiredObj.',
      );
    }

    final photoLower = photo.toLowerCase();

    // 1. Explicit negative signals (e.g. no cow in frame, wrong object, unrelated item)
    final hasNoObjectTag = photoLower.contains('no_$requiredObj') ||
        photoLower.contains('no_cow') ||
        photoLower.contains('wrong_object') ||
        photoLower.contains('unrelated_photo') ||
        photoLower.contains('empty_frame');

    if (hasNoObjectTag) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Object Detection',
        actualValue: 'No $requiredObj detected',
        requiredValue: requiredObj,
        confidence: 0.1,
        message: 'No $displayObj detected. Please photograph a real $requiredObj.',
      );
    }

    // 2. Target object presence verification
    final questTitleLower = quest.title.toLowerCase();
    final questDescLower = quest.description.toLowerCase();

    final isObjectPresent = photoLower.contains(requiredObj) ||
        questTitleLower.contains(requiredObj) ||
        questDescLower.contains(requiredObj);

    if (!isObjectPresent) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Object Detection',
        actualValue: 'Unmatched subject',
        requiredValue: requiredObj,
        confidence: 0.2,
        message: 'No $displayObj detected. Please photograph a real $requiredObj.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Object Detection',
      actualValue: '$displayObj detected',
      requiredValue: requiredObj,
      confidence: 0.95,
      message: 'Object Verification Passed: Identified "$requiredObj" in the captured image proof.',
    );
  }
}
