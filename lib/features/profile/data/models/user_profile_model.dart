import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    super.playerId = 'QST-0000',
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
      id: json['id'] as String? ?? json['user_id'] as String? ?? 'user_default',
      playerId: json['playerId'] as String? ?? json['player_id'] as String? ?? 'QST-0000',
      name: json['name'] as String? ?? 'Alex Nova',
      email: json['email'] as String? ?? 'alex.explorer@questup.app',
      avatarKey: json['avatarKey'] as String? ?? json['avatar_key'] as String? ?? 'avatar_cyber_knight',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? json['current_xp'] as int? ?? 120,
      xpToNextLevel: json['xpToNextLevel'] as int? ?? json['xp_to_next_level'] as int? ?? 500,
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
          : (json['joined_at'] != null ? DateTime.tryParse(json['joined_at'] as String) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerId': playerId,
      'player_id': playerId,
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
      playerId: entity.playerId,
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
