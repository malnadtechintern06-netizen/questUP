import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel extends LeaderboardEntry {
  const LeaderboardEntryModel({
    required super.userId,
    super.playerTag,
    required super.userName,
    required super.avatarKey,
    required super.rank,
    required super.level,
    required super.xp,
    required super.completedQuestsCount,
    super.isCurrentUser = false,
    super.totalParticipants,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      userId: (json['userId'] ?? json['user_id'] ?? '') as String,
      playerTag: (json['playerTag'] ?? json['player_id'] ?? json['player_tag']) as String?,
      userName: (json['userName'] ?? json['username'] ?? json['display_name'] ?? 'Explorer') as String,
      avatarKey: (json['avatarKey'] ?? json['avatar_key'] ?? json['avatar_url'] ?? 'avatar_ranger') as String,
      rank: int.tryParse(json['rank'].toString()) ?? 1,
      level: int.tryParse(json['level'].toString()) ?? 1,
      xp: int.tryParse(json['xp'].toString()) ?? int.tryParse(json['total_xp'].toString()) ?? 0,
      completedQuestsCount: int.tryParse((json['completedQuestsCount'] ?? json['completed_quests_count']).toString()) ?? 0,
      isCurrentUser: json['isCurrentUser'] == true || json['is_current_user'] == true,
      totalParticipants: int.tryParse((json['totalParticipants'] ?? json['total_participants']).toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'playerTag': playerTag,
      'userName': userName,
      'avatarKey': avatarKey,
      'rank': rank,
      'level': level,
      'xp': xp,
      'completedQuestsCount': completedQuestsCount,
      'isCurrentUser': isCurrentUser,
      'totalParticipants': totalParticipants,
    };
  }

  factory LeaderboardEntryModel.fromEntity(LeaderboardEntry entity) {
    return LeaderboardEntryModel(
      userId: entity.userId,
      playerTag: entity.playerTag,
      userName: entity.userName,
      avatarKey: entity.avatarKey,
      rank: entity.rank,
      level: entity.level,
      xp: entity.xp,
      completedQuestsCount: entity.completedQuestsCount,
      isCurrentUser: entity.isCurrentUser,
      totalParticipants: entity.totalParticipants,
    );
  }
}
