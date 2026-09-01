import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class TimedActivityVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Activity Duration Timer';

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final actual = payload.durationSeconds ?? 0;
    final target = quest.requiredDurationSeconds;

    if (target > 0 && actual < target) {
      final remaining = target - actual;
      return ValidatorResult(
        passed: false,
        validatorName: 'Activity Duration Timer',
        actualValue: _formatTime(actual),
        requiredValue: _formatTime(target),
        message: 'Timer Incomplete: Elapsed time is ${_formatTime(actual)}. You need ${_formatTime(remaining)} more to complete the goal.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Activity Duration Timer',
      actualValue: _formatTime(actual),
      requiredValue: _formatTime(target),
      message: 'Activity Duration Verified: Completed full session of ${_formatTime(actual)}.',
    );
  }
}
