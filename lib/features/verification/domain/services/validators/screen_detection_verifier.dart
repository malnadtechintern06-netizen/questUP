import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import '../scene_authenticity_service.dart';
import 'i_validator.dart';

class ScreenDetectionVerifier implements IQuestValidator {
  final ISceneAuthenticityService _authenticityService;

  const ScreenDetectionVerifier([ISceneAuthenticityService authenticityService = const SceneAuthenticityService()])
      : _authenticityService = authenticityService;

  @override
  String get validatorName => 'Screen / Photo-of-Photo Detection';

  @override
  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  }) async {
    final photo = payload.photoProofPath;
    if (photo == null || photo.trim().isEmpty) {
      return const ValidatorResult(
        passed: false,
        validatorName: 'Screen / Photo-of-Photo Detection',
        actualValue: 'No photo provided',
        requiredValue: 'Real-world photograph',
        message: 'Screen Detection Failed: No photograph submitted for authenticity analysis.',
      );
    }

    final targetSubject = quest.requiredObject ?? quest.requiredPlace ?? 'subject';

    final assessment = await _authenticityService.analyzeSceneAuthenticity(
      photoPath: photo,
      requiredObject: quest.requiredObject,
      requiresFreshCapture: quest.requiresFreshPhoto,
    );

    // 1. Digital Screen / Monitor / Phone Screen Detection
    if (assessment.isScreenDetected) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Screen / Photo-of-Photo Detection',
        actualValue: 'Displayed Image / Screen Detected',
        requiredValue: 'Physical Real-World $targetSubject',
        confidence: assessment.confidence,
        message: 'Please photograph a real $targetSubject, not an image displayed on another phone, computer, or digital screen.',
      );
    }

    // 2. Printed Photograph / Poster Detection
    if (assessment.isPhotoOfPhoto) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Screen / Photo-of-Photo Detection',
        actualValue: 'Printed Image / Poster Detected',
        requiredValue: 'Physical Real-World $targetSubject',
        confidence: assessment.confidence,
        message: 'This appears to be a photo of a printed image or poster. Please photograph a real $targetSubject in its natural environment.',
      );
    }

    // 3. Extreme Tight Crop / Zero Scene Context
    if (assessment.isCroppedTight || assessment.status == SceneAuthenticityStatus.insufficientContext) {
      return ValidatorResult(
        passed: false,
        validatorName: 'Scene Authenticity & Context',
        actualValue: 'Insufficient Environmental Context',
        requiredValue: 'Real-world scene with natural surroundings',
        confidence: assessment.confidence,
        message: 'We couldn\'t confidently verify this photo. Please take another photo of the $targetSubject in a wider real-world scene with its surroundings visible.',
      );
    }

    // 4. Authenticity Passed
    return ValidatorResult(
      passed: true,
      validatorName: 'Screen / Photo-of-Photo Detection',
      actualValue: 'Authentic Real-World Scene',
      requiredValue: 'Real-World Photograph',
      confidence: assessment.confidence,
      message: 'Scene Authenticity Verified: Confirmed physical real-world environment with no screen or display artifacts.',
    );
  }
}
