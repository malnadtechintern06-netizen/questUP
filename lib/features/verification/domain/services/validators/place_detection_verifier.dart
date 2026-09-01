import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class PlaceDetectionVerifier implements IQuestValidator {
  @override
  String get validatorName => 'Place & Target Verification';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final requiredPlace = quest.requiredPlace?.trim().toLowerCase();
    final requiredTarget = quest.requiredTarget?.trim().toLowerCase();

    if ((requiredPlace == null || requiredPlace.isEmpty) &&
        (requiredTarget == null || requiredTarget.isEmpty)) {
      return const ValidatorResult(
        passed: true,
        validatorName: 'Place & Target Verification',
        actualValue: 'General Waypoint',
        requiredValue: 'Any place',
        message: 'No specific place or target verification required.',
      );
    }

    final locNameLower = quest.locationName.toLowerCase();
    final placeCatLower = (quest.placeCategory ?? '').toLowerCase();

    final placeMatched = requiredPlace == null ||
        locNameLower.contains(requiredPlace) ||
        placeCatLower.contains(requiredPlace) ||
        (payload.photoProofPath != null && payload.photoProofPath!.toLowerCase().contains(requiredPlace));

    if (!placeMatched) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Place & Target Verification',
        actualValue: quest.locationName,
        requiredValue: '$requiredPlace ${requiredTarget ?? ''}'.trim(),
        message: 'Place Verification Failed: Location does not match the required place type "$requiredPlace".',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'Place & Target Verification',
      actualValue: '${quest.locationName} (${requiredTarget ?? 'Site'})',
      requiredValue: '${requiredPlace ?? 'Place'} ${requiredTarget ?? ''}'.trim(),
      message: 'Place Verified: Waypoint confirmed at ${quest.locationName}.',
    );
  }
}
