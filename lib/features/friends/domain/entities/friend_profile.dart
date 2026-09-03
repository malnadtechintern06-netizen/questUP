class FriendCompletedQuestSummary {
  final String questId;
  final String title;
  final String category;
  final int xpEarned;
  final int coinsEarned;
  final DateTime completedAt;
  final String locationName;

  const FriendCompletedQuestSummary({
    required this.questId,
    required this.title,
    required this.category,
    required this.xpEarned,
    required this.coinsEarned,
    required this.completedAt,
    required this.locationName,
  });
}

class FriendBadgeSummary {
  final String badgeId;
  final String title;
  final String tier;
  final String iconKey;
  final bool isHardcore;
  final DateTime? unlockedAt;

  const FriendBadgeSummary({
    required this.badgeId,
    required this.title,
    required this.tier,
    required this.iconKey,
    required this.isHardcore,
    this.unlockedAt,
  });
}

class FriendProfile {
  final String userId;
  final String playerTag;
  final String name;
  final String avatarKey;
  final int level;
  final int currentXp;
  final int coins;
  final int rank;
  final String rankTitle;
  final int completedQuestsCount;
  final int gamesPlayedCount;
  final List<FriendCompletedQuestSummary> completedQuests;
  final List<FriendBadgeSummary> earnedBadges;
  final DateTime friendshipDate;
  final bool isOnline;
  final String lastActiveText;

  const FriendProfile({
    required this.userId,
    required this.playerTag,
    required this.name,
    required this.avatarKey,
    required this.level,
    required this.currentXp,
    required this.coins,
    required this.rank,
    required this.rankTitle,
    required this.completedQuestsCount,
    required this.gamesPlayedCount,
    required this.completedQuests,
    required this.earnedBadges,
    required this.friendshipDate,
    required this.isOnline,
    required this.lastActiveText,
  });

  FriendProfile copyWith({
    String? userId,
    String? playerTag,
    String? name,
    String? avatarKey,
    int? level,
    int? currentXp,
    int? coins,
    int? rank,
    String? rankTitle,
    int? completedQuestsCount,
    int? gamesPlayedCount,
    List<FriendCompletedQuestSummary>? completedQuests,
    List<FriendBadgeSummary>? earnedBadges,
    DateTime? friendshipDate,
    bool? isOnline,
    String? lastActiveText,
  }) {
    return FriendProfile(
      userId: userId ?? this.userId,
      playerTag: playerTag ?? this.playerTag,
      name: name ?? this.name,
      avatarKey: avatarKey ?? this.avatarKey,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      coins: coins ?? this.coins,
      rank: rank ?? this.rank,
      rankTitle: rankTitle ?? this.rankTitle,
      completedQuestsCount: completedQuestsCount ?? this.completedQuestsCount,
      gamesPlayedCount: gamesPlayedCount ?? this.gamesPlayedCount,
      completedQuests: completedQuests ?? this.completedQuests,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      friendshipDate: friendshipDate ?? this.friendshipDate,
      isOnline: isOnline ?? this.isOnline,
      lastActiveText: lastActiveText ?? this.lastActiveText,
    );
  }
}
