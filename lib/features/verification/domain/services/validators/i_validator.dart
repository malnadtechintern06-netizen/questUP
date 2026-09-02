import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';

class VerificationProofPayload {
  final double? userLat;
  final double? userLon;
  final double? locationAccuracy;
  final DateTime? capturedAt;
  final String? photoProofPath;
  final bool isFreshCameraCapture;
  final String? photoAttemptId;
  final String? sessionId;
  final QuestSession? questSession;
  final String? mediaHash;
  final String? videoProofPath;
  final int? durationSeconds;
  final String? textContent;
  final int? wordCount;
  final int? lineCount;
  final String? drawingProofSummary;
  final int? strokeCount;
  final double? distanceMeters;
  final int? gameplaySeconds;
  final int? repetitionCount;
  final bool isPasted;
  final int? pastedCharactersCount;
  final int? keystrokeCount;
  final bool isAuthenticallyTyped;

  const VerificationProofPayload({
    this.userLat,
    this.userLon,
    this.locationAccuracy,
    this.capturedAt,
    this.photoProofPath,
    this.isFreshCameraCapture = false,
    this.photoAttemptId,
    this.sessionId,
    this.questSession,
    this.mediaHash,
    this.videoProofPath,
    this.durationSeconds,
    this.textContent,
    this.wordCount,
    this.lineCount,
    this.drawingProofSummary,
    this.strokeCount,
    this.distanceMeters,
    this.gameplaySeconds,
    this.repetitionCount,
    this.isPasted = false,
    this.pastedCharactersCount = 0,
    this.keystrokeCount,
    this.isAuthenticallyTyped = true,
  });
}

abstract class IQuestValidator {
  String get validatorName;

  Future<ValidatorResult> validate({
    required Quest quest,
    required QuestAttempt attempt,
    required VerificationProofPayload payload,
  });
}
