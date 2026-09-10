import 'validator_result.dart';

enum VerificationStatus {
  verified,
  pending,
  rejected,
}

class QuestCompletion {
  final String id;
  final String questId;
  final String userId;
  final String? attemptId;
  final DateTime completedAt;
  final double userLatitude;
  final double userLongitude;
  final String photoProofPath;
  final VerificationStatus status;
  final int xpEarned;
  final int coinsEarned;
  final List<ValidatorResult> validatorResults;

  const QuestCompletion({
    required this.id,
    required this.questId,
    required this.userId,
    this.attemptId,
    required this.completedAt,
    required this.userLatitude,
    required this.userLongitude,
    required this.photoProofPath,
    required this.status,
    required this.xpEarned,
    required this.coinsEarned,
    this.validatorResults = const [],
  });
}

class VerificationResult {
  final bool isSuccessful;
  final String message;
  final bool isGpsValid;
  final bool isCameraValid;
  final QuestCompletion? completion;
  final int xpEarned;
  final int coinsEarned;
  final bool didLevelUp;
  final int newLevel;
  final String? unlockedBadgeTitle;
  final List<ValidatorResult> validatorResults;
  final bool isPendingAdminReview;

  const VerificationResult({
    required this.isSuccessful,
    required this.message,
    required this.isGpsValid,
    required this.isCameraValid,
    this.completion,
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.didLevelUp = false,
    this.newLevel = 1,
    this.unlockedBadgeTitle,
    this.validatorResults = const [],
    this.isPendingAdminReview = false,
  });
}
