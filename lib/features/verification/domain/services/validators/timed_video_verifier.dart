import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class TimedVideoVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Timed Video Verification';

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
        validatorName: 'Timed Video Verification',
        actualValue: _formatTime(actual),
        requiredValue: _formatTime(target),
        message: 'Duration Incomplete: Completed ${_formatTime(actual)} / ${_formatTime(target)}. Need ${_formatTime(remaining)} more continuous session time.',
      );
    }

    if (payload.videoProofPath == null || payload.videoProofPath!.isEmpty) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Timed Video Verification',
        actualValue: 'No video recorded',
        requiredValue: 'Recorded Video Proof',
        message: 'Video Proof Required: Please record your activity session using the in-app camera.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Timed Video Verification',
      actualValue: '${_formatTime(actual)} recorded',
      requiredValue: _formatTime(target),
      message: 'Timed Video Verified: Completed continuous session of ${_formatTime(actual)} with valid video proof.',
    );
  }
}
