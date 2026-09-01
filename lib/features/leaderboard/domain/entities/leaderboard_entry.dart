class LeaderboardEntry {
  final String userId;
  final String userName;
  final String avatarKey;
  final int rank;
  final int level;
  final int xp;
  final int completedQuestsCount;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.avatarKey,
    required this.rank,
    required this.level,
    required this.xp,
    required this.completedQuestsCount,
    this.isCurrentUser = false,
  });

  LeaderboardEntry copyWith({
    String? userId,
    String? userName,
    String? avatarKey,
    int? rank,
    int? level,
    int? xp,
    int? completedQuestsCount,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarKey: avatarKey ?? this.avatarKey,
      rank: rank ?? this.rank,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      completedQuestsCount: completedQuestsCount ?? this.completedQuestsCount,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
