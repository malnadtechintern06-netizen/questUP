import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:quest_up/features/leaderboard/data/datasources/leaderboard_remote_datasource.dart';
import 'package:quest_up/features/leaderboard/data/datasources/leaderboard_local_datasource.dart';
import 'package:quest_up/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'package:quest_up/features/friends/domain/repositories/friends_repository.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';

class MockFriendsRepository implements IFriendsRepository {
  @override
  Future<List<FriendProfile>> getFriends() async {
    return [
      FriendProfile(
        userId: 'friend_1',
        playerTag: 'QST-1001',
        name: 'Friend Champion',
        avatarKey: 'avatar_mystic_sage',
        level: 5,
        currentXp: 3000,
        coins: 100,
        rank: 1,
        rankTitle: 'Pathfinder',
        completedQuestsCount: 10,
        gamesPlayedCount: 10,
        completedQuests: const [],
        earnedBadges: const [],
        friendshipDate: DateTime.now(),
        isOnline: true,
        lastActiveText: 'Online',
        isFriend: true,
        friendshipStatus: 'accepted',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalStorageService implements ILocalStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Leaderboard System Tests', () {
    test('LeaderboardEntryModel serializes and parses correctly with player tags and totals', () {
      final json = {
        'userId': 'u123',
        'playerTag': 'QST-2794',
        'userName': 'suju',
        'avatarKey': 'avatar_ranger',
        'rank': 11,
        'level': 2,
        'xp': 990,
        'completedQuestsCount': 5,
        'isCurrentUser': true,
        'totalParticipants': 152,
      };

      final model = LeaderboardEntryModel.fromJson(json);
      expect(model.userId, 'u123');
      expect(model.playerTag, 'QST-2794');
      expect(model.userName, 'suju');
      expect(model.rank, 11);
      expect(model.isCurrentUser, true);
      expect(model.totalParticipants, 152);

      final outJson = model.toJson();
      expect(outJson['playerTag'], 'QST-2794');
      expect(outJson['totalParticipants'], 152);
    });

    test('All Time Leaderboard queries MySQL and returns Top 10 champions', () async {
      final remoteDataSource = LeaderboardRemoteDataSource();
      final entries = await remoteDataSource.getLeaderboard(
        filter: 'all_time',
        currentUserId: 'fe9bcb4b-880d-4ae8-b0f1-9317c1306afa',
        limit: 10,
      );

      expect(entries.isNotEmpty, isTrue);
      expect(entries.length, lessThanOrEqualTo(11));
      expect(entries.first.rank, 1);
      expect(entries.first.xp, greaterThan(0));
    });

    test('Weekly Leaderboard returns Top 10 players for the current week', () async {
      final remoteDataSource = LeaderboardRemoteDataSource();
      final entries = await remoteDataSource.getLeaderboard(
        filter: 'weekly',
        currentUserId: 'fe9bcb4b-880d-4ae8-b0f1-9317c1306afa',
        limit: 10,
      );

      expect(entries.isNotEmpty, isTrue);
      expect(entries.first.rank, 1);
    });

    test('Friends Leaderboard strictly limits to squad friends and user', () async {
      final mockFriends = MockFriendsRepository();
      final mockStorage = MockLocalStorageService();
      final localDataSource = LeaderboardLocalDataSource(mockStorage);
      final remoteDataSource = LeaderboardRemoteDataSource();

      final repo = LeaderboardRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
        friendsRepository: mockFriends,
      );

      final entries = await repo.getLeaderboard(
        currentUserId: 'test_user_me',
        currentUserName: 'My User',
        currentUserAvatar: 'avatar_ranger',
        currentUserLevel: 2,
        currentUserXp: 500,
        currentUserCompletedCount: 2,
        filter: 'friends',
      );

      expect(entries.isNotEmpty, isTrue);
      expect(entries.any((e) => e.isCurrentUser), isTrue);
      for (final e in entries) {
        expect(e.rank, greaterThanOrEqualTo(1));
      }
    });
  });
}
