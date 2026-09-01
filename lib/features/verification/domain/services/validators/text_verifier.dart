import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class TextVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Text Submission';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final text = payload.textContent?.trim();
    if (text == null || text.isEmpty) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Text Submission',
        actualValue: 'Empty response',
        requiredValue: 'Written Text Content',
        message: 'Text Content Required: Please compose your response in the editor before submitting.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Text Submission',
      actualValue: '${text.length} characters written',
      requiredValue: 'Written Text',
      message: 'Text Submission Verified: Response submitted successfully.',
    );
  }
}
