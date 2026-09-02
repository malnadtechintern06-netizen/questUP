import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import '../duplicate_proof_service.dart';
import 'i_validator.dart';

class DuplicateProofVerifier implements IQuestValidator {
  final IDuplicateProofService duplicateProofService;

  DuplicateProofVerifier(this.duplicateProofService);

  @override
  String get validatorName => 'Duplicate Proof';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final hash = payload.mediaHash;

    if (hash == null || hash.isEmpty) {
      // If no media hash is supplied (e.g. Pure GPS quests), duplicate check passes
      return const ValidatorResult(
        passed: true,
        validatorName: 'Duplicate Proof',
        actualValue: 'N/A (Non-Media Quest)',
        requiredValue: 'Unique Proof',
        message: 'Duplicate Check: Not applicable for this quest type.',
      );
    }

    final isDuplicate = await duplicateProofService.isDuplicateProof(
      hash,
      currentQuestId: quest.id,
      currentUserId: attempt.userId,
    );

    if (isDuplicate) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Duplicate Proof',
        actualValue: 'Duplicate Media Fingerprint',
        requiredValue: 'Unique Fresh Proof',
        message: 'This proof has already been used. Please capture or submit unique fresh proof.',
      );
    }

    return const ValidatorResult(
      passed: true,
      validatorName: 'Duplicate Proof',
      actualValue: 'Unique SHA-256 Hash',
      requiredValue: 'Unique Media Fingerprint',
      message: 'Proof Uniqueness Verified: No duplicate proof detected.',
    );
  }
}
