import 'dart:async';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_local_datasource.dart';
import '../datasources/leaderboard_remote_datasource.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../../verification/data/datasources/verification_local_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final ILeaderboardRemoteDataSource remoteDataSource;
  final ILeaderboardLocalDataSource localDataSource;
  final IFriendsRepository friendsRepository;
  final IVerificationLocalDataSource? verificationLocalDataSource;

  // In-memory cache for 0ms instant tab switching & immediate display
  final Map<String, List<LeaderboardEntry>> _memoryCache = {};
  final StreamController<Map<String, List<LeaderboardEntry>>> _updateStreamController =
      StreamController<Map<String, List<LeaderboardEntry>>>.broadcast();

  LeaderboardRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.friendsRepository,
    this.verificationLocalDataSource,
  });

  Stream<Map<String, List<LeaderboardEntry>>> get updates => _updateStreamController.stream;

  void clearCache() {
    _memoryCache.clear();
  }

  String _getCacheKey(String currentUserId, String filter) => '$currentUserId:$filter';

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
    final cacheKey = _getCacheKey(currentUserId, filter);

    // 1. If memory cache has data for THIS user, return immediately in 0ms
    if (_memoryCache.containsKey(cacheKey) && _memoryCache[cacheKey]!.isNotEmpty) {
      _refreshInBackground(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        currentUserLevel: currentUserLevel,
        currentUserXp: currentUserXp,
        currentUserCompletedCount: currentUserCompletedCount,
        filter: filter,
      );
      return _memoryCache[cacheKey]!;
    }

    // 2. On first open, load local baseline instantly (< 5ms) to display screen immediately
    final localBaseline = await _getLocalBaseline(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatar: currentUserAvatar,
      currentUserLevel: currentUserLevel,
      currentUserXp: currentUserXp,
      currentUserCompletedCount: currentUserCompletedCount,
      filter: filter,
    );

    if (localBaseline.isNotEmpty) {
      _memoryCache[cacheKey] = localBaseline;
      // Trigger background sync with server without blocking UI
      _refreshInBackground(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        currentUserLevel: currentUserLevel,
        currentUserXp: currentUserXp,
        currentUserCompletedCount: currentUserCompletedCount,
        filter: filter,
      );
      return localBaseline;
    }

    // 3. If no local baseline, fetch and cache
    return await _fetchAndCache(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatar: currentUserAvatar,
      currentUserLevel: currentUserLevel,
      currentUserXp: currentUserXp,
      currentUserCompletedCount: currentUserCompletedCount,
      filter: filter,
    );
  }

  void _refreshInBackground({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    required String filter,
  }) {
    Future.microtask(() async {
      try {
        final fresh = await _fetchFromRemote(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,
          currentUserLevel: currentUserLevel,
          currentUserXp: currentUserXp,
          currentUserCompletedCount: currentUserCompletedCount,
          filter: filter,
        );
        if (fresh.isNotEmpty) {
          final cacheKey = _getCacheKey(currentUserId, filter);
          _memoryCache[cacheKey] = fresh;
          _updateStreamController.add(_memoryCache);
        }
      } catch (_) {}
    });
  }

  Future<List<LeaderboardEntry>> _fetchAndCache({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    required String filter,
  }) async {
    final cacheKey = _getCacheKey(currentUserId, filter);
    final remote = await _fetchFromRemote(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatar: currentUserAvatar,
      currentUserLevel: currentUserLevel,
      currentUserXp: currentUserXp,
      currentUserCompletedCount: currentUserCompletedCount,
      filter: filter,
    );

    if (remote.isNotEmpty) {
      _memoryCache[cacheKey] = remote;
      return remote;
    }

    final offline = await _getLocalBaseline(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatar: currentUserAvatar,
      currentUserLevel: currentUserLevel,
      currentUserXp: currentUserXp,
      currentUserCompletedCount: currentUserCompletedCount,
      filter: filter,
    );
    _memoryCache[cacheKey] = offline;
    return offline;
  }

  Future<List<LeaderboardEntry>> _fetchFromRemote({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    required String filter,
  }) async {
    try {
      final remoteEntries = await remoteDataSource
          .getLeaderboard(
            filter: filter,
            currentUserId: currentUserId,
            limit: 10,
          )
          .timeout(const Duration(milliseconds: 1200), onTimeout: () => []);

      if (remoteEntries.isNotEmpty) {
        return remoteEntries.map((e) {
          final isMe = (currentUserId.isNotEmpty && (e.userId == currentUserId || e.playerTag == currentUserId));
          if (isMe) {
            return e.copyWith(
              userName: currentUserName.isNotEmpty ? currentUserName : e.userName,
              avatarKey: currentUserAvatar.isNotEmpty ? currentUserAvatar : e.avatarKey,
              isCurrentUser: true,
            );
          }
          return e.copyWith(isCurrentUser: false);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<LeaderboardEntry>> _getLocalBaseline({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
    required String filter,
  }) async {
    switch (filter) {
      case 'friends':
        return await _getFriendsLeaderboardOffline(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,
          currentUserLevel: currentUserLevel,
          currentUserXp: currentUserXp,
          currentUserCompletedCount: currentUserCompletedCount,
        );
      case 'weekly':
        return await _getWeeklyLeaderboardOffline(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,
          currentUserLevel: currentUserLevel,
          currentUserXp: currentUserXp,
          currentUserCompletedCount: currentUserCompletedCount,
        );
      case 'all_time':
      default:
        return await _getAllTimeLeaderboardOffline(
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
  Future<List<LeaderboardEntry>> _getFriendsLeaderboardOffline({
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
        playerTag: friend.playerTag,
        userName: friend.name,
        avatarKey: friend.avatarKey,
        rank: 0,
        level: friend.level,
        xp: friend.currentXp,
        completedQuestsCount: friend.completedQuestsCount,
        isCurrentUser: false,
      );
    }

    if (currentUserId.isNotEmpty) {
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
    }

    final entries = entriesMap.values.toList();
    entries.sort((a, b) {
      final xpCompare = b.xp.compareTo(a.xp);
      if (xpCompare != 0) return xpCompare;
      return b.completedQuestsCount.compareTo(a.completedQuestsCount);
    });

    final totalCount = entries.length;
    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < entries.length; i++) {
      ranked.add(entries[i].copyWith(rank: i + 1, totalParticipants: totalCount));
    }
    return ranked;
  }

  /// Weekly Tab: Top performers in the current week (Offline Baseline).
  Future<List<LeaderboardEntry>> _getWeeklyLeaderboardOffline({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required int currentUserLevel,
    required int currentUserXp,
    required int currentUserCompletedCount,
  }) async {
    final weeklyCompetitors = await localDataSource.getWeeklyCompetitors();
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    int userWeeklyXp = 0;
    int userWeeklyCompletions = 0;

    if (verificationLocalDataSource != null && currentUserId.isNotEmpty) {
      try {
        final completions = await verificationLocalDataSource!.getCompletions(currentUserId);
        final recentCompletions = completions.where((c) => c.completedAt.isAfter(oneWeekAgo)).toList();
        userWeeklyXp = recentCompletions.fold<int>(0, (sum, c) => sum + c.xpEarned);
        userWeeklyCompletions = recentCompletions.length;
      } catch (_) {}
    }

    if (userWeeklyXp == 0 && currentUserXp > 0) {
      userWeeklyXp = (currentUserXp * 0.22).round();
      userWeeklyCompletions = (currentUserCompletedCount * 0.22).ceil().clamp(1, 10);
    }

    final entriesMap = <String, LeaderboardEntry>{};

    for (final comp in weeklyCompetitors) {
      entriesMap[comp.userId] = comp;
    }

    final allFriends = await friendsRepository.getFriends();
    for (final f in allFriends.where((f) => f.isFriend || f.friendshipStatus == 'accepted')) {
      if (f.userId == currentUserId) continue;
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
        playerTag: f.playerTag,
        userName: f.name,
        avatarKey: f.avatarKey,
        rank: 0,
        level: f.level,
        xp: friendWeeklyXp,
        completedQuestsCount: friendWeeklyCount,
        isCurrentUser: false,
      );
    }

    if (currentUserId.isNotEmpty) {
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
    }

    final entries = entriesMap.values.toList();
    entries.sort((a, b) {
      final xpCompare = b.xp.compareTo(a.xp);
      if (xpCompare != 0) return xpCompare;
      return b.completedQuestsCount.compareTo(a.completedQuestsCount);
    });

    final totalCount = entries.length;
    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < entries.length; i++) {
      ranked.add(entries[i].copyWith(rank: i + 1, totalParticipants: totalCount));
    }
    return ranked;
  }

  /// All Time Tab: Global overall leaderboard of all players and competitors (Offline Baseline).
  Future<List<LeaderboardEntry>> _getAllTimeLeaderboardOffline({
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

    final allFriends = await friendsRepository.getFriends();
    for (final f in allFriends.where((f) => f.isFriend || f.friendshipStatus == 'accepted')) {
      if (f.userId == currentUserId) continue;
      entriesMap[f.userId] = LeaderboardEntry(
        userId: f.userId,
        playerTag: f.playerTag,
        userName: f.name,
        avatarKey: f.avatarKey,
        rank: 0,
        level: f.level,
        xp: f.currentXp,
        completedQuestsCount: f.completedQuestsCount,
        isCurrentUser: false,
      );
    }

    if (currentUserId.isNotEmpty) {
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
    }

    final entries = entriesMap.values.toList();
    entries.sort((a, b) {
      final xpCompare = b.xp.compareTo(a.xp);
      if (xpCompare != 0) return xpCompare;
      return b.completedQuestsCount.compareTo(a.completedQuestsCount);
    });

    final totalCount = entries.length;
    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < entries.length; i++) {
      ranked.add(entries[i].copyWith(rank: i + 1, totalParticipants: totalCount));
    }
    return ranked;
  }
}
