import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class LineCountVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Line Count Requirement';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final target = quest.requiredLines;
    if (target <= 0) {
      return const ValidatorResult(
        passed: true,
        validatorName: 'Line Count Requirement',
        actualValue: 'No line count target',
        requiredValue: '0 lines',
        message: 'No line count requirement specified.',
      );
    }

    int actual = payload.lineCount ?? 0;
    if (actual == 0 && payload.textContent != null) {
      actual = payload.textContent!.trim().split('\n').length;
    }

    if (actual < target) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Line Count Requirement',
        actualValue: '$actual lines',
        requiredValue: '$target lines',
        message: 'Line Count Incomplete: You wrote $actual lines. At least $target lines are required.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Line Count Requirement',
      actualValue: '$actual lines',
      requiredValue: '$target lines',
      message: 'Line Count Verified: Requirement met with $actual lines.',
    );
  }
}
