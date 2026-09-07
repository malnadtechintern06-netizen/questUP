import 'package:flutter/foundation.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'i_validator.dart';

class GpsVerifier implements IQuestValidator {
  @override
  String get validatorName => 'GPS Geofence';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    if (payload.userLat == null || payload.userLon == null) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'GPS Geofence',
        actualValue: 'No GPS Coordinates',
        requiredValue: 'Active GPS Satellite Signal',
        message: 'GPS Satellite Signal Required: Unable to acquire your live coordinates.',
      );
    }

    final distance = DistanceCalculator.calculateDistanceMeters(
      lat1: payload.userLat!,
      lon1: payload.userLon!,
      lat2: quest.latitude,
      lon2: quest.longitude,
    );

    // Safe debug output for location quest verification
    debugPrint('[QuestUP Location Quest] Distance to destination: ${distance.round()} m');

    final requiredRadius = quest.radiusMeters > 0 ? quest.radiusMeters : 100.0;
    final isWithinRadius = distance <= requiredRadius;

    if (!isWithinRadius) {
      return ValidatorResult(
        passed: false,
        validatorName: 'GPS Geofence',
        actualValue: DistanceCalculator.formatDistance(distance),
        requiredValue: 'within ${DistanceCalculator.formatDistance(requiredRadius)}',
        message: 'GPS Proximity Check Failed: You are ${DistanceCalculator.formatDistance(distance)} away from ${quest.locationName}. Move within ${requiredRadius.round()}m to verify.',
      );
    }

    return ValidatorResult(
      passed: true,
      validatorName: 'GPS Geofence',
      actualValue: '${DistanceCalculator.formatDistance(distance)} away',
      requiredValue: 'within ${DistanceCalculator.formatDistance(requiredRadius)}',
      message: 'GPS Geofence Verified: Player is at ${quest.locationName} (${DistanceCalculator.formatDistance(distance)} from target).',
    );
  }
}
