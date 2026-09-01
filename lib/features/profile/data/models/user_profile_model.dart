import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.name,
    required super.email,
    required super.avatarKey,
    required super.level,
    required super.currentXp,
    required super.xpToNextLevel,
    required super.coins,
    required super.completedQuestIds,
    required super.earnedBadgeIds,
    required super.joinedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? 'user_default',
      name: json['name'] as String? ?? 'Alex Nova',
      email: json['email'] as String? ?? 'alex.explorer@questup.app',
      avatarKey: json['avatarKey'] as String? ?? 'avatar_cyber_knight',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? 120,
      xpToNextLevel: json['xpToNextLevel'] as int? ?? 500,
      coins: json['coins'] as int? ?? 250,
      completedQuestIds: (json['completedQuestIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      earnedBadgeIds: (json['earnedBadgeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['badge_first_step'],
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarKey': avatarKey,
      'level': level,
      'currentXp': currentXp,
      'xpToNextLevel': xpToNextLevel,
      'coins': coins,
      'completedQuestIds': completedQuestIds,
      'earnedBadgeIds': earnedBadgeIds,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory UserProfileModel.fromEntity(UserProfile entity) {
    return UserProfileModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      avatarKey: entity.avatarKey,
      level: entity.level,
      currentXp: entity.currentXp,
      xpToNextLevel: entity.xpToNextLevel,
      coins: entity.coins,
      completedQuestIds: entity.completedQuestIds,
      earnedBadgeIds: entity.earnedBadgeIds,
      joinedAt: entity.joinedAt,
    );
  }
}
