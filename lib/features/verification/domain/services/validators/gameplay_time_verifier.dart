import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class GameplayTimeVerifier implements IQuestValidator {
  @override
  String get validatorName => 'In-App Gameplay Time';

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
    final actual = payload.gameplaySeconds ?? payload.durationSeconds ?? 0;
    final target = quest.requiredDurationSeconds > 0 ? quest.requiredDurationSeconds : 180;

    if (actual < target) {
      final remaining = target - actual;
      return ValidatorResult(
        passed: false,
        validatorName: 'In-App Gameplay Time',
        actualValue: _formatTime(actual),
        requiredValue: _formatTime(target),
        message: 'Gameplay Incomplete: ${_formatTime(actual)} / ${_formatTime(target)} played. Keep playing for ${_formatTime(remaining)} more.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'In-App Gameplay Time',
      actualValue: '${_formatTime(actual)} played',
      requiredValue: _formatTime(target),
      message: 'Gameplay Verified: Completed ${_formatTime(actual)} active game session.',
    );
  }
}
