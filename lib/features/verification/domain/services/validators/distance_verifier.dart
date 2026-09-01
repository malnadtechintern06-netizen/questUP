import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class DistanceVerifier implements IQuestValidator {
  @override
  String get validatorName => 'GPS Walking Distance';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final actual = payload.distanceMeters ?? 0.0;
    final target = quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000.0;

    if (actual < target) {
      final remaining = target - actual;
      return ValidatorResult(
        passed: false,
        validatorName: 'GPS Walking Distance',
        actualValue: DistanceCalculator.formatDistance(actual),
        requiredValue: DistanceCalculator.formatDistance(target),
        message: 'Walking Goal Incomplete: You walked ${DistanceCalculator.formatDistance(actual)} / ${DistanceCalculator.formatDistance(target)}. Need ${DistanceCalculator.formatDistance(remaining)} more.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'GPS Walking Distance',
      actualValue: '${DistanceCalculator.formatDistance(actual)} covered',
      requiredValue: DistanceCalculator.formatDistance(target),
      message: 'Walking Distance Verified: Successfully covered ${DistanceCalculator.formatDistance(actual)} via live GPS tracking.',
    );
  }
}
