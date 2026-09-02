import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class SessionVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Quest Session';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final session = payload.questSession;

    if (session == null) {
      // If no explicit session is attached, validate attempt timestamp within 24h window
      final now = DateTime.now();
      final isExpired = now.difference(attempt.startedAt).inHours > 24;

      if (isExpired) {
        return const ValidatorResult(
          passed: false,
          validatorName: 'Quest Session',
          actualValue: 'Expired (>24 hours)',
          requiredValue: 'Active Session (<24 hours)',
          message: 'Quest Session Expired: Your attempt started more than 24 hours ago. Please start a fresh quest session.',
        );
      }

      return ValidatorResult(
        passed: true,
        validatorName: 'Quest Session',
        actualValue: 'Attempt ID: ${attempt.attemptId}',
        requiredValue: 'Active Session',
        message: 'Quest Session Validated: Active session verified.',
      );
    }

    if (session.questId != quest.id) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Quest Session',
        actualValue: 'Quest ID ${session.questId}',
        requiredValue: 'Quest ID ${quest.id}',
        message: 'Invalid Quest Session: This session was created for a different quest.',
      );
    }

    if (session.isExpired) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Quest Session',
        actualValue: 'Expired Session',
        requiredValue: 'Active Session',
        message: 'Quest Session Expired: Your quest session has expired. Please restart the quest.',
      );
    }

    if (session.status == QuestSessionStatus.verified) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Quest Session',
        actualValue: 'Already Verified',
        requiredValue: 'In-Progress Session',
        message: 'Session Replay Blocked: This quest session has already been completed and rewarded.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Quest Session',
      actualValue: 'Session ${session.sessionId}',
      requiredValue: 'Active Session',
      message: 'Quest Session Valid: Active session verified.',
    );
  }
}
