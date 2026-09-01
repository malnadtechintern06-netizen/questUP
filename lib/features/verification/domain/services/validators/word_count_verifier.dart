import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class WordCountVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Word Count Requirement';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final target = quest.requiredWords;
    if (target <= 0) {
      return const ValidatorResult(
        passed: true,
        validatorName: 'Word Count Requirement',
        actualValue: 'No word count target',
        requiredValue: '0 words',
        message: 'No specific word count requirement.',
      );
    }

    int actual = payload.wordCount ?? 0;
    if (actual == 0 && payload.textContent != null && payload.textContent!.trim().isNotEmpty) {
      actual = payload.textContent!
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
    }

    if (actual < target) {
      final remaining = target - actual;
      return ValidatorResult(
        passed: false,
        validatorName: 'Word Count Requirement',
        actualValue: '$actual words',
        requiredValue: '$target words',
        message: 'Word Count Incomplete: You wrote $actual / $target words. Please add $remaining more words.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Word Count Requirement',
      actualValue: '$actual words',
      requiredValue: '$target words',
      message: 'Word Count Verified: Target achieved with $actual words written.',
    );
  }
}
