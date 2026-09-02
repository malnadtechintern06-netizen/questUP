import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class TimedVideoVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Timed Video Verification';

  String _formatReadableTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes minutes $seconds seconds';
    } else if (minutes > 0) {
      return '$minutes minutes';
    } else {
      return '$seconds seconds';
    }
  }

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final actual = payload.durationSeconds ?? 0;
    final target = quest.requiredDurationSeconds;

    if (payload.videoProofPath == null || payload.videoProofPath!.isEmpty) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Timed Video Verification',
        actualValue: 'No video recorded',
        requiredValue: 'Recorded Video Proof',
        message: 'Video Proof Required: Please record and submit your activity session video.',
      );
    }

    if (target > 0 && actual < target) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Timed Video Verification',
        actualValue: _formatReadableTime(actual),
        requiredValue: _formatReadableTime(target),
        message: 'Duration Incomplete: Your video is only ${_formatReadableTime(actual)}. You need at least ${_formatReadableTime(target)}.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Timed Video Verification',
      actualValue: '${_formatReadableTime(actual)} recorded',
      requiredValue: _formatReadableTime(target),
      message: 'Duration Requirement Satisfied: Activity video recorded for ${_formatReadableTime(actual)}.',
    );
  }
}
