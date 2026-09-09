import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_local_datasource.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../../verification/data/datasources/verification_local_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final ILeaderboardLocalDataSource localDataSource;
  final IFriendsRepository friendsRepository;
  final IVerificationLocalDataSource? verificationLocalDataSource;

  LeaderboardRepositoryImpl({
    required this.localDataSource,
    required this.friendsRepository,
    this.verificationLocalDataSource,
  });

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
    switch (filter) {
      case 'friends':
        return _getFriendsLeaderboard(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,
          currentUserLevel: currentUserLevel,
          currentUserXp: currentUserXp,
          currentUserCompletedCount: currentUserCompletedCount,
        );
      case 'weekly':
        return _getWeeklyLeaderboard(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,
          currentUserLevel: currentUserLevel,
          currentUserXp: currentUserXp,
          currentUserCompletedCount: currentUserCompletedCount,
        );
      case 'all_time':
      default:
        return _getAllTimeLeaderboard(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,
          currentUserLevel: currentUserLevel,
          currentUserXp: currentUserXp,
          currentUserCompletedCount: currentUserCompletedCount,
        );
    }
  }

  /// Friends Only: Compare current player with accepted squad friends only.
  Future<List<LeaderboardEntry>> _getFriendsLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
  }) async {
    final allFriends = await friendsRepository.getFriends();
    final acceptedFriends = allFriends
        .where((f) => f.isFriend || f.friendshipStatus == 'accepted')
        .toList();

    final entriesMap = <String, LeaderboardEntry>{};

    for (final friend in acceptedFriends) {
      if (friend.userId == currentUserId) continue;
      entriesMap[friend.userId] = LeaderboardEntry(
        userId: friend.userId,
        userName: friend.name,
        avatarKey: friend.avatarKey,
        rank: 0,
        level: friend.level,
        xp: friend.currentXp,
        completedQuestsCount: friend.completedQuestsCount,
        isCurrentUser: false,
      );
    }

    // Always include the current player to compare standings
    entriesMap[currentUserId] = LeaderboardEntry(
      userId: currentUserId,
      userName: currentUserName,
      avatarKey: currentUserAvatar,
      rank: 0,
      level: currentUserLevel,
      xp: currentUserXp,
      completedQuestsCount: currentUserCompletedCount,
      isCurrentUser: true,
    );

    final entries = entriesMap.values.toList();
    entries.sort((a, b) {
      final xpCompare = b.xp.compareTo(a.xp);
      if (xpCompare != 0) return xpCompare;
      return b.completedQuestsCount.compareTo(a.completedQuestsCount);
    });

    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < entries.length; i++) {
      ranked.add(entries[i].copyWith(rank: i + 1));
    }
    return ranked;
  }

  /// Weekly Tab: Top performers in the current week.
  Future<List<LeaderboardEntry>> _getWeeklyLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
  }) async {
    final weeklyCompetitors = await localDataSource.getWeeklyCompetitors();
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    // Calculate user's weekly XP and completions
    int userWeeklyXp = 0;
    int userWeeklyCompletions = 0;

    if (verificationLocalDataSource != null) {
      try {
        final completions = await verificationLocalDataSource!.getCompletions(currentUserId);
        final recentCompletions = completions.where((c) => c.completedAt.isAfter(oneWeekAgo)).toList();
        userWeeklyXp = recentCompletions.fold<int>(0, (sum, c) => sum + c.xpEarned);
        userWeeklyCompletions = recentCompletions.length;
      } catch (_) {}
    }

    // If no recent verified completion logged yet but user has all-time XP,
    // grant proportional weekly activity so user has a presence
    if (userWeeklyXp == 0 && currentUserXp > 0) {
      userWeeklyXp = (currentUserXp * 0.35).round();
      userWeeklyCompletions = (currentUserCompletedCount * 0.35).ceil().clamp(1, 10);
    }

    final entriesMap = <String, LeaderboardEntry>{};

    for (final comp in weeklyCompetitors) {
      entriesMap[comp.userId] = comp;
    }

    // Include any accepted squad friends with their weekly XP
    final allFriends = await friendsRepository.getFriends();
    for (final f in allFriends.where((f) => f.isFriend || f.friendshipStatus == 'accepted')) {
      if (f.userId == currentUserId) continue;
      // Calculate weekly portion for friend
      int friendWeeklyXp = 0;
      int friendWeeklyCount = 0;
      if (f.completedQuests.isNotEmpty) {
        final recentQuests = f.completedQuests.where((q) => q.completedAt.isAfter(oneWeekAgo));
        friendWeeklyXp = recentQuests.fold<int>(0, (s, q) => s + q.xpEarned);
        friendWeeklyCount = recentQuests.length;
      }
      if (friendWeeklyXp == 0 && f.currentXp > 0) {
        friendWeeklyXp = (f.currentXp * 0.2).round();
        friendWeeklyCount = 1;
      }

      entriesMap[f.userId] = LeaderboardEntry(
        userId: f.userId,
        userName: f.name,
        avatarKey: f.avatarKey,
        rank: 0,
        level: f.level,
        xp: friendWeeklyXp,
        completedQuestsCount: friendWeeklyCount,
        isCurrentUser: false,
      );
    }

    // Current user weekly entry
    entriesMap[currentUserId] = LeaderboardEntry(
      userId: currentUserId,
      userName: currentUserName,
      avatarKey: currentUserAvatar,
      rank: 0,
      level: currentUserLevel,
      xp: userWeeklyXp,
      completedQuestsCount: userWeeklyCompletions,
      isCurrentUser: true,
    );

    final entries = entriesMap.values.toList();
    entries.sort((a, b) {
      final xpCompare = b.xp.compareTo(a.xp);
      if (xpCompare != 0) return xpCompare;
      return b.completedQuestsCount.compareTo(a.completedQuestsCount);
    });

    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < entries.length; i++) {
      ranked.add(entries[i].copyWith(rank: i + 1));
    }
    return ranked;
  }

  /// All Time Tab: Global overall leaderboard of all players and competitors.
  Future<List<LeaderboardEntry>> _getAllTimeLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
  }) async {
    final competitors = await localDataSource.getCompetitors();
    final entriesMap = <String, LeaderboardEntry>{};

    for (final comp in competitors) {
      entriesMap[comp.userId] = comp;
    }

    // Include friends in global rankings as well
    final allFriends = await friendsRepository.getFriends();
    for (final f in allFriends.where((f) => f.isFriend || f.friendshipStatus == 'accepted')) {
      if (f.userId == currentUserId) continue;
      entriesMap[f.userId] = LeaderboardEntry(
        userId: f.userId,
        userName: f.name,
        avatarKey: f.avatarKey,
        rank: 0,
        level: f.level,
        xp: f.currentXp,
        completedQuestsCount: f.completedQuestsCount,
        isCurrentUser: false,
      );
    }

    // Current user
    entriesMap[currentUserId] = LeaderboardEntry(
      userId: currentUserId,
      userName: currentUserName,
      avatarKey: currentUserAvatar,
      rank: 0,
      level: currentUserLevel,
      xp: currentUserXp,
      completedQuestsCount: currentUserCompletedCount,
      isCurrentUser: true,
    );

    final entries = entriesMap.values.toList();
    entries.sort((a, b) {
      final xpCompare = b.xp.compareTo(a.xp);
      if (xpCompare != 0) return xpCompare;
      return b.completedQuestsCount.compareTo(a.completedQuestsCount);
    });

    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < entries.length; i++) {
      ranked.add(entries[i].copyWith(rank: i + 1));
    }
    return ranked;
  }
}
