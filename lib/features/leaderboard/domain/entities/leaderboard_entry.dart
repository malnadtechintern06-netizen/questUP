class LeaderboardEntry {
  final String userId;
  final String? playerTag;
  final String userName;
  final String avatarKey;
  final int rank;
  final int level;
  final int xp;
  final int completedQuestsCount;
  final bool isCurrentUser;
  final int? totalParticipants;

  const LeaderboardEntry({
    required this.userId,
    this.playerTag,
    required this.userName,
    required this.avatarKey,
    required this.rank,
    required this.level,
    required this.xp,
    required this.completedQuestsCount,
    this.isCurrentUser = false,
    this.totalParticipants,
  });

  LeaderboardEntry copyWith({
    String? userId,
    String? playerTag,
    String? userName,
    String? avatarKey,
    int? rank,
    int? level,
    int? xp,
    int? completedQuestsCount,
    bool? isCurrentUser,
    int? totalParticipants,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      playerTag: playerTag ?? this.playerTag,
      userName: userName ?? this.userName,
      avatarKey: avatarKey ?? this.avatarKey,
      rank: rank ?? this.rank,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      completedQuestsCount: completedQuestsCount ?? this.completedQuestsCount,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      totalParticipants: totalParticipants ?? this.totalParticipants,
    );
  }
}
