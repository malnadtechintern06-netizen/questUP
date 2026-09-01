import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class RepetitionVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Repetition Count';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final target = quest.requiredRepetitions;
    if (target <= 0) {
      return const ValidatorResult(
        passed: true,
        validatorName: 'Repetition Count',
        actualValue: 'No repetition target',
        requiredValue: '0 reps',
        message: 'No repetition target specified.',
      );
    }

    final actual = payload.repetitionCount ?? 0;
    if (actual < target) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Repetition Count',
        actualValue: '$actual reps',
        requiredValue: '$target reps',
        message: 'Repetition Target Incomplete: Completed $actual / $target repetitions.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Repetition Count',
      actualValue: '$actual reps',
      requiredValue: '$target reps',
      message: 'Repetition Target Verified: Completed $actual repetitions.',
    );
  }
}
