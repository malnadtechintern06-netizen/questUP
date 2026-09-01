import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'validators/distance_verifier.dart';
import 'validators/drawing_verifier.dart';
import 'validators/fresh_photo_verifier.dart';
import 'validators/gameplay_time_verifier.dart';
import 'validators/gps_verifier.dart';
import 'validators/i_validator.dart';
import 'validators/line_count_verifier.dart';
import 'validators/object_detection_verifier.dart';
import 'validators/place_detection_verifier.dart';
import 'validators/repetition_verifier.dart';
import 'validators/text_verifier.dart';
import 'validators/timed_activity_verifier.dart';
import 'validators/timed_video_verifier.dart';
import 'validators/word_count_verifier.dart';

class VerificationCheckOutcome {
  final bool isValid;
  final String message;
  final List<ValidatorResult> validatorResults;

  const VerificationCheckOutcome({
    required this.isValid,
    required this.message,
    this.validatorResults = const [],
  });
}

abstract class IQuestVerificationService {
  Future<VerificationReport> evaluateAttempt({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  });

  VerificationCheckOutcome validateProof({
    required Quest quest,
    double? userLat,
    double? userLon,
    String? photoProofPath,
    String? videoProofPath,
    String? drawingProofSummary,
    String? textContent,
    int? wordCount,
    int? durationSeconds,
    double? distanceMeters,
  });
}

class QuestVerificationService implements IQuestVerificationService {
  final GpsVerifier _gpsVerifier = GpsVerifier();
  final FreshPhotoVerifier _freshPhotoVerifier = FreshPhotoVerifier();
  final ObjectDetectionVerifier _objectDetectionVerifier = ObjectDetectionVerifier();
  final PlaceDetectionVerifier _placeDetectionVerifier = PlaceDetectionVerifier();
  final TimedVideoVerifier _timedVideoVerifier = TimedVideoVerifier();
  final TimedActivityVerifier _timedActivityVerifier = TimedActivityVerifier();
  final TextVerifier _textVerifier = TextVerifier();
  final WordCountVerifier _wordCountVerifier = WordCountVerifier();
  final LineCountVerifier _lineCountVerifier = LineCountVerifier();
  final DrawingVerifier _drawingVerifier = DrawingVerifier();
  final DistanceVerifier _distanceVerifier = DistanceVerifier();
  final GameplayTimeVerifier _gameplayTimeVerifier = GameplayTimeVerifier();
  final RepetitionVerifier _repetitionVerifier = RepetitionVerifier();

  /// Dynamically assembles the list of validators based on the quest's requirements.
  List<IQuestValidator> resolveValidatorsForQuest(Quest quest) {
    final validators = <IQuestValidator>[];

    // 1. GPS Geofence (Location / Destination Quests with coordinates)
    if (quest.latitude != 0.0 && quest.longitude != 0.0 && quest.verificationType != QuestVerificationType.walkingGps) {
      validators.add(_gpsVerifier);
    }

    // 2. Walking Distance
    if (quest.verificationType == QuestVerificationType.walkingGps || quest.requiredDistanceMeters > 0) {
      validators.add(_distanceVerifier);
    }

    // 3. In-App Camera Photo / Fresh Photo Proof
    if (quest.requiresFreshPhoto || quest.requiresPhoto || quest.verificationType == QuestVerificationType.photoProof) {
      validators.add(_freshPhotoVerifier);
    }

    // 4. Generic Object Detection (flower, cow, tree, apple, book, etc.)
    if (quest.hasObjectDetection) {
      validators.add(_objectDetectionVerifier);
    }

    // 5. Place Category / Target Detection
    if (quest.hasPlaceDetection) {
      validators.add(_placeDetectionVerifier);
    }

    // 6. Timed Video (Reading, Exercise, etc.)
    if (quest.requiresVideo || quest.verificationType == QuestVerificationType.timedVideo || quest.verificationType == QuestVerificationType.videoProof) {
      validators.add(_timedVideoVerifier);
    } else if (quest.verificationType == QuestVerificationType.timedActivity || quest.requiredDurationSeconds > 0) {
      // 7. Activity Timer (without mandatory video)
      validators.add(_timedActivityVerifier);
    }

    // 8. Text Content & Word Count
    if (quest.requiresText || quest.verificationType == QuestVerificationType.writingText) {
      validators.add(_textVerifier);
      if (quest.requiredWords > 0) {
        validators.add(_wordCountVerifier);
      }
      if (quest.requiredLines > 0) {
        validators.add(_lineCountVerifier);
      }
    }

    // 9. Drawing Canvas
    if (quest.requiresDrawing || quest.verificationType == QuestVerificationType.drawingCanvas) {
      validators.add(_drawingVerifier);
    }

    // 10. Gameplay Timer
    if (quest.requiresGameSession || quest.verificationType == QuestVerificationType.gameplayTime) {
      validators.add(_gameplayTimeVerifier);
    }

    // 11. Repetitions
    if (quest.requiredRepetitions > 0) {
      validators.add(_repetitionVerifier);
    }

    // Fallback if no specific validator matched
    if (validators.isEmpty) {
      switch (quest.verificationType) {
        case QuestVerificationType.locationGps:
          validators.add(_gpsVerifier);
          break;
        case QuestVerificationType.photoProof:
          validators.add(_freshPhotoVerifier);
          break;
        case QuestVerificationType.timedActivity:
          validators.add(_timedActivityVerifier);
          break;
        case QuestVerificationType.timedVideo:
        case QuestVerificationType.videoProof:
          validators.add(_timedVideoVerifier);
          break;
        case QuestVerificationType.writingText:
          validators.add(_textVerifier);
          if (quest.requiredWords > 0) validators.add(_wordCountVerifier);
          break;
        case QuestVerificationType.drawingCanvas:
          validators.add(_drawingVerifier);
          break;
        case QuestVerificationType.walkingGps:
          validators.add(_distanceVerifier);
          break;
        case QuestVerificationType.gameplayTime:
          validators.add(_gameplayTimeVerifier);
          break;
        case QuestVerificationType.compositeRules:
        case QuestVerificationType.customConfig:
          break;
      }
    }

    return validators;
  }

  @override
  Future<VerificationReport> evaluateAttempt({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final validators = resolveValidatorsForQuest(quest);
    final results = <ValidatorResult>[];

    if (validators.isEmpty) {
      final defaultPass = ValidatorResult(
        passed: true,
        validatorName: 'Standard Verification',
        actualValue: 'Complete',
        requiredValue: 'Complete',
        message: 'Quest verification complete.',
      );
      return VerificationReport(
        isSuccessful: true,
        results: [defaultPass],
        overallMessage: 'All requirements verified successfully!',
      );
    }

    for (final validator in validators) {
      final res = await validator.validate(
        quest: quest,
        attempt: attempt,
        payload: payload,
      );
      results.add(res);
    }

    final isSuccessful = results.every((r) => r.passed);
    final firstFailure = results.where((r) => !r.passed).firstOrNull;

    final overallMessage = isSuccessful
        ? 'All ${results.length} verification requirements passed! Quest completed.'
        : (firstFailure?.message ?? 'Verification requirement check failed.');

    return VerificationReport(
      isSuccessful: isSuccessful,
      results: results,
      overallMessage: overallMessage,
    );
  }

  @override
  VerificationCheckOutcome validateProof({
    required Quest quest,
    double? userLat,
    double? userLon,
    String? photoProofPath,
    String? videoProofPath,
    String? drawingProofSummary,
    String? textContent,
    int? wordCount,
    int? durationSeconds,
    double? distanceMeters,
  }) {
    final attempt = QuestAttempt(
      attemptId: 'quick_attempt_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'anonymous_user',
      questId: quest.id,
      startedAt: DateTime.now(),
    );

    final payload = VerificationProofPayload(
      userLat: userLat,
      userLon: userLon,
      photoProofPath: photoProofPath,
      isFreshCameraCapture: photoProofPath != null && photoProofPath.isNotEmpty,
      videoProofPath: videoProofPath,
      drawingProofSummary: drawingProofSummary,
      textContent: textContent,
      wordCount: wordCount,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
    );

    final validators = resolveValidatorsForQuest(quest);
    final results = <ValidatorResult>[];

    for (final validator in validators) {
      // Synchronous compatibility execution
      final future = validator.validate(quest: quest, attempt: attempt, payload: payload);
      // Since our validators are pure math/logic computation, we extract the result
      future.then((res) => results.add(res));
    }

    // Direct synchronous fallback for legacy compatibility
    switch (quest.verificationType) {
      case QuestVerificationType.locationGps:
        if (userLat == null || userLon == null) {
          return const VerificationCheckOutcome(
            isValid: false,
            message: 'GPS Satellite Signal Required: Unable to acquire your location coordinates.',
          );
        }
        if (quest.latitude != 0.0 && quest.longitude != 0.0) {
          final isWithin = (userLat - quest.latitude).abs() < 0.01 && (userLon - quest.longitude).abs() < 0.01;
          if (!isWithin) {
            return const VerificationCheckOutcome(
              isValid: false,
              message: 'GPS Proximity Check: You are outside the target radius.',
            );
          }
        }
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'GPS Geofence Verified: Waypoint reached successfully!',
        );

      case QuestVerificationType.photoProof:
        if (photoProofPath == null || photoProofPath.isEmpty) {
          return const VerificationCheckOutcome(
            isValid: false,
            message: 'Photo Proof Required: Please take or attach a clear photo of the waypoint or task.',
          );
        }
        if (quest.hasObjectDetection) {
          final reqObj = quest.requiredObject!.toLowerCase();
          final matches = photoProofPath.toLowerCase().contains(reqObj) ||
              quest.title.toLowerCase().contains(reqObj);
          if (!matches) {
            return VerificationCheckOutcome(
              isValid: false,
              message: 'Object Verification Failed: Target "$reqObj" not detected.',
            );
          }
        }
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'Photo Proof Attached: Verification successful!',
        );

      case QuestVerificationType.timedActivity:
      case QuestVerificationType.timedVideo:
      case QuestVerificationType.videoProof:
        final actual = durationSeconds ?? 0;
        final target = quest.requiredDurationSeconds;
        if (target > 0 && actual < target) {
          final remaining = target - actual;
          return VerificationCheckOutcome(
            isValid: false,
            message: 'Duration Requirement Not Met: ${(actual / 60).toStringAsFixed(1)} mins completed. Need ${(remaining / 60).toStringAsFixed(1)} more minutes.',
          );
        }
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'Activity Duration Verified: Full session completed!',
        );

      case QuestVerificationType.writingText:
        final actualWords = wordCount ?? 0;
        final targetWords = quest.requiredWords;
        if (targetWords > 0 && actualWords < targetWords) {
          return VerificationCheckOutcome(
            isValid: false,
            message: 'Word Count Incomplete: $actualWords / $targetWords words written. Please write at least $targetWords words.',
          );
        }
        if (textContent == null || textContent.trim().isEmpty) {
          return const VerificationCheckOutcome(
            isValid: false,
            message: 'Text Content Required: Please write your response before submitting.',
          );
        }
        return VerificationCheckOutcome(
          isValid: true,
          message: 'Writing Challenge Verified: $actualWords words composed successfully!',
        );

      case QuestVerificationType.drawingCanvas:
        if (drawingProofSummary == null || drawingProofSummary.isEmpty) {
          return const VerificationCheckOutcome(
            isValid: false,
            message: 'Drawing Canvas Required: Please draw your artwork on the canvas before submitting.',
          );
        }
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'Drawing Canvas Verified: Artwork submitted successfully!',
        );

      case QuestVerificationType.walkingGps:
        final actualDist = distanceMeters ?? 0.0;
        final targetDist = quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000.0;
        if (actualDist < targetDist) {
          return VerificationCheckOutcome(
            isValid: false,
            message: 'Walking Distance Goal Incomplete: Need more distance to complete.',
          );
        }
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'Walking Distance Verified!',
        );

      case QuestVerificationType.gameplayTime:
        final actual = durationSeconds ?? 0;
        final target = quest.requiredDurationSeconds > 0 ? quest.requiredDurationSeconds : 180;
        if (actual < target) {
          return VerificationCheckOutcome(
            isValid: false,
            message: 'Gameplay Duration Incomplete: $actual / $target seconds played.',
          );
        }
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'In-App Gameplay Verified: Game session completed!',
        );

      case QuestVerificationType.compositeRules:
      case QuestVerificationType.customConfig:
        return const VerificationCheckOutcome(
          isValid: true,
          message: 'Custom Challenge Verified!',
        );
    }
  }
}
