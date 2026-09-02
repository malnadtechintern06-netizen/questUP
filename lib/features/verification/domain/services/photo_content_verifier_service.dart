import 'dart:io';
import 'scene_authenticity_service.dart';

enum ContentVerificationResultStatus {
  pass,
  fail,
  reviewRequired,
}

class ContentVerificationResult {
  final ContentVerificationResultStatus status;
  final String message;
  final double? confidence;
  final bool isScreenDetected;
  final bool isPhotoOfPhoto;
  final double sceneContextScore;
  final Map<String, dynamic> metadata;

  const ContentVerificationResult({
    required this.status,
    required this.message,
    this.confidence,
    this.isScreenDetected = false,
    this.isPhotoOfPhoto = false,
    this.sceneContextScore = 1.0,
    this.metadata = const {},
  });

  bool get isPassed => status == ContentVerificationResultStatus.pass;
}

abstract class IPhotoContentVerificationService {
  Future<ContentVerificationResult> verifyPhotoContent({
    required String photoPath,
    required String? requiredObject,
    required String? requiredPlace,
    required bool requiresFreshPhoto,
  });
}

class PhotoContentVerificationService implements IPhotoContentVerificationService {
  final ISceneAuthenticityService _authenticityService;

  const PhotoContentVerificationService([ISceneAuthenticityService authenticityService = const SceneAuthenticityService()])
      : _authenticityService = authenticityService;

  @override
  Future<ContentVerificationResult> verifyPhotoContent({
    required String photoPath,
    required String? requiredObject,
    required String? requiredPlace,
    required bool requiresFreshPhoto,
  }) async {
    if (photoPath.isEmpty) {
      return const ContentVerificationResult(
        status: ContentVerificationResultStatus.fail,
        message: 'No photo proof provided for content verification.',
      );
    }

    try {
      final file = File(photoPath);
      final exists = await file.exists();

      if (exists) {
        final length = await file.length();
        if (length < 100) {
          return const ContentVerificationResult(
            status: ContentVerificationResultStatus.fail,
            message: 'Photo proof file is corrupted or empty (0 bytes).',
          );
        }
      }

      final target = requiredObject ?? requiredPlace;

      // Evaluate Anti-Cheat Scene Authenticity & Screen Detection
      final assessment = await _authenticityService.analyzeSceneAuthenticity(
        photoPath: photoPath,
        requiredObject: requiredObject,
        requiresFreshCapture: requiresFreshPhoto,
      );

      if (assessment.isScreenDetected) {
        return ContentVerificationResult(
          status: ContentVerificationResultStatus.fail,
          message: 'Screen display detected: Please photograph a real ${target ?? "subject"}, not a picture displayed on another screen.',
          confidence: assessment.confidence,
          isScreenDetected: true,
          isPhotoOfPhoto: true,
          sceneContextScore: 0.1,
          metadata: {
            'target': target,
            'screenBezelDetected': true,
            'provider': 'SmartProofEngine_v1',
          },
        );
      }

      if (assessment.isPhotoOfPhoto) {
        return ContentVerificationResult(
          status: ContentVerificationResultStatus.fail,
          message: 'Printed image detected: Please photograph a real ${target ?? "subject"} in its natural environment.',
          confidence: assessment.confidence,
          isScreenDetected: false,
          isPhotoOfPhoto: true,
          sceneContextScore: 0.2,
          metadata: {
            'target': target,
            'isPhotoOfPhoto': true,
            'provider': 'SmartProofEngine_v1',
          },
        );
      }

      if (assessment.status == SceneAuthenticityStatus.insufficientContext) {
        return ContentVerificationResult(
          status: ContentVerificationResultStatus.reviewRequired,
          message: 'Insufficient scene context: Please take another photo of the ${target ?? "subject"} with its natural surroundings visible.',
          confidence: assessment.confidence,
          isScreenDetected: false,
          isPhotoOfPhoto: false,
          sceneContextScore: 0.3,
          metadata: {
            'target': target,
            'tightCrop': true,
            'provider': 'SmartProofEngine_v1',
          },
        );
      }

      if (target == null || target.isEmpty) {
        return const ContentVerificationResult(
          status: ContentVerificationResultStatus.pass,
          message: 'General photo proof validated successfully.',
        );
      }

      return ContentVerificationResult(
        status: ContentVerificationResultStatus.pass,
        message: 'Photo proof submitted matching target "$target".',
        confidence: assessment.confidence,
        isScreenDetected: false,
        isPhotoOfPhoto: false,
        sceneContextScore: 0.95,
        metadata: {
          'target': target,
          'fileSize': exists ? await file.length() : null,
          'provider': 'SmartProofEngine_v1',
        },
      );
    } catch (e) {
      return ContentVerificationResult(
        status: ContentVerificationResultStatus.reviewRequired,
        message: 'Content verification pending review: $e',
      );
    }
  }
}
