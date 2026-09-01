import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel extends LeaderboardEntry {
  const LeaderboardEntryModel({
    required super.userId,
    required super.userName,
    required super.avatarKey,
    required super.rank,
    required super.level,
    required super.xp,
    required super.completedQuestsCount,
    super.isCurrentUser = false,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      avatarKey: json['avatarKey'] as String? ?? 'avatar_ranger',
      rank: json['rank'] as int? ?? 1,
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      completedQuestsCount: json['completedQuestsCount'] as int? ?? 0,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarKey': avatarKey,
      'rank': rank,
      'level': level,
      'xp': xp,
      'completedQuestsCount': completedQuestsCount,
      'isCurrentUser': isCurrentUser,
    };
  }

  factory LeaderboardEntryModel.fromEntity(LeaderboardEntry entity) {
    return LeaderboardEntryModel(
      userId: entity.userId,
      userName: entity.userName,
      avatarKey: entity.avatarKey,
      rank: entity.rank,
      level: entity.level,
      xp: entity.xp,
      completedQuestsCount: entity.completedQuestsCount,
      isCurrentUser: entity.isCurrentUser,
    );
  }
}
