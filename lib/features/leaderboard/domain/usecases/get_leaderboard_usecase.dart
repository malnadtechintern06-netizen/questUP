import '../entities/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

class GetLeaderboardUseCase {
  final LeaderboardRepository _repository;

  const GetLeaderboardUseCase(this._repository);

  Future<List<LeaderboardEntry>> call({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    String filter = 'all_time',
  }) async {
    return await _repository.getLeaderboard(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatar: currentUserAvatar,
      currentUserLevel: currentUserLevel,
      currentUserXp: currentUserXp,
      currentUserCompletedCount: currentUserCompletedCount,
      filter: filter,
    );
  }
}
