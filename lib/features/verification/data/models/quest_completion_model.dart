import '../../domain/entities/quest_completion.dart';

class QuestCompletionModel extends QuestCompletion {
  const QuestCompletionModel({
    required super.id,
    required super.questId,
    required super.userId,
    required super.completedAt,
    required super.userLatitude,
    required super.userLongitude,
    required super.photoProofPath,
    required super.status,
    required super.xpEarned,
    required super.coinsEarned,
  });

  factory QuestCompletionModel.fromJson(Map<String, dynamic> json) {
    return QuestCompletionModel(
      id: json['id'] as String,
      questId: json['questId'] as String,
      userId: json['userId'] as String,
      completedAt: DateTime.tryParse(json['completedAt'] as String) ?? DateTime.now(),
      userLatitude: (json['userLatitude'] as num).toDouble(),
      userLongitude: (json['userLongitude'] as num).toDouble(),
      photoProofPath: json['photoProofPath'] as String? ?? '',
      status: VerificationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => VerificationStatus.verified,
      ),
      xpEarned: json['xpEarned'] as int? ?? 0,
      coinsEarned: json['coinsEarned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': questId,
      'userId': userId,
      'completedAt': completedAt.toIso8601String(),
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'photoProofPath': photoProofPath,
      'status': status.name,
      'xpEarned': xpEarned,
      'coinsEarned': coinsEarned,
    };
  }

  factory QuestCompletionModel.fromEntity(QuestCompletion entity) {
    return QuestCompletionModel(
      id: entity.id,
      questId: entity.questId,
      userId: entity.userId,
      completedAt: entity.completedAt,
      userLatitude: entity.userLatitude,
      userLongitude: entity.userLongitude,
      photoProofPath: entity.photoProofPath,
      status: entity.status,
      xpEarned: entity.xpEarned,
      coinsEarned: entity.coinsEarned,
    );
  }
}
