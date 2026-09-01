class UserProfile {
  final String id;
  final String name;
  final String email;
  final String avatarKey;
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final int coins;
  final List<String> completedQuestIds;
  final List<String> earnedBadgeIds;
  final DateTime joinedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarKey,
    required this.level,
    required this.currentXp,
    required this.xpToNextLevel,
    required this.coins,
    required this.completedQuestIds,
    required this.earnedBadgeIds,
    required this.joinedAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarKey,
    int? level,
    int? currentXp,
    int? xpToNextLevel,
    int? coins,
    List<String>? completedQuestIds,
    List<String>? earnedBadgeIds,
    DateTime? joinedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarKey: avatarKey ?? this.avatarKey,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      coins: coins ?? this.coins,
      completedQuestIds: completedQuestIds ?? this.completedQuestIds,
      earnedBadgeIds: earnedBadgeIds ?? this.earnedBadgeIds,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
