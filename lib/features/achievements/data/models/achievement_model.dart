import '../../domain/entities/achievement.dart';

class AchievementModel extends Achievement {
  const AchievementModel({
    required super.id,
    required super.title,
    required super.description,
    required super.iconKey,
    super.requiredQuestCount = 0,
    super.requiredLevel = 1,
    super.requiredCoins = 0,
    super.isUnlocked = false,
    super.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconKey: json['iconKey'] as String? ?? 'badge',
      requiredQuestCount: json['requiredQuestCount'] as int? ?? 0,
      requiredLevel: json['requiredLevel'] as int? ?? 1,
      requiredCoins: json['requiredCoins'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconKey': iconKey,
      'requiredQuestCount': requiredQuestCount,
      'requiredLevel': requiredLevel,
      'requiredCoins': requiredCoins,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory AchievementModel.fromEntity(Achievement entity) {
    return AchievementModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      iconKey: entity.iconKey,
      requiredQuestCount: entity.requiredQuestCount,
      requiredLevel: entity.requiredLevel,
      requiredCoins: entity.requiredCoins,
      isUnlocked: entity.isUnlocked,
      unlockedAt: entity.unlockedAt,
    );
  }
}
