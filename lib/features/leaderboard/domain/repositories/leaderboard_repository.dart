import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    String filter = 'all_time', // 'all_time', 'weekly', 'friends'
  });
}
