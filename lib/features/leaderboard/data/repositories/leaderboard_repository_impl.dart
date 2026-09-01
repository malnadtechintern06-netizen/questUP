import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_local_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final ILeaderboardLocalDataSource _localDataSource;

  LeaderboardRepositoryImpl(this._localDataSource);

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    String filter = 'all_time',
  }) async {
    final competitors = await _localDataSource.getCompetitors();

    final currentUserEntry = LeaderboardEntry(
      userId: currentUserId,
      userName: currentUserName,
      avatarKey: currentUserAvatar,
      rank: 0,
      level: currentUserLevel,
      xp: currentUserXp,
      completedQuestsCount: currentUserCompletedCount,
      isCurrentUser: true,
    );

    final allEntries = <LeaderboardEntry>[
      ...competitors.where((c) => c.userId != currentUserId),
      currentUserEntry,
    ];

    // Sort descending by XP
    allEntries.sort((a, b) => b.xp.compareTo(a.xp));

    // Assign dynamic ranks
    final rankedList = <LeaderboardEntry>[];
    for (int i = 0; i < allEntries.length; i++) {
      rankedList.add(allEntries[i].copyWith(rank: i + 1));
    }

    return rankedList;
  }
}
