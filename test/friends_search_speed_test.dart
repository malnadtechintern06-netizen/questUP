import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/friends/data/datasources/friends_local_datasource.dart';
import 'package:quest_up/features/friends/data/datasources/friends_remote_datasource.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:quest_up/features/profile/data/datasources/user_local_datasource.dart';
import 'package:quest_up/features/profile/data/repositories/user_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ILocalStorageService storage;
  late IFriendsLocalDataSource localDataSource;
  late IFriendsRemoteDataSource remoteDataSource;
  late UserRepositoryImpl userRepo;
  late FriendsRepositoryImpl friendsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    final userLocalDataSource = UserLocalDataSource(storage);
    userRepo = UserRepositoryImpl(userLocalDataSource);
    localDataSource = FriendsLocalDataSource(storage);
    remoteDataSource = FriendsRemoteDataSource();
    friendsRepo = FriendsRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      userRepository: userRepo,
    );

    // Seed a real registered explorer in local storage
    await localDataSource.savePlayerRegistry([
      FriendProfileModel(
        userId: 'usr_rohan_123',
        playerTag: 'QST-7249',
        name: 'Rohan Scout',
        avatarKey: 'avatar_ranger',
        level: 3,
        currentXp: 800,
        coins: 250,
        rank: 2,
        rankTitle: 'Pathfinder',
        completedQuestsCount: 5,
        gamesPlayedCount: 6,
        completedQuests: const [],
        earnedBadges: const [],
        friendshipDate: DateTime(2026, 1, 1),
        isOnline: true,
        lastActiveText: 'Active on Radar',
        isFriend: false,
        friendshipStatus: 'none',
      ),
    ]);
  });

  group('Friends Search Performance & Real Player Resolution', () {
    test('1. Search for 7249 returns real player Rohan Scout and completes fast', () async {
      final stopwatch = Stopwatch()..start();
      final player = await friendsRepo.searchPlayer('7249');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3500));
      expect(player, isNotNull);
      expect(player!.playerTag, equals('QST-7249'));
      expect(player.name, equals('Rohan Scout'));
      expect(player.userId.startsWith('comp_'), isFalse);
    });

    test('2. Search for #QST-7249 strips prefix and finds real player', () async {
      final player = await friendsRepo.searchPlayer('#QST-7249');
      expect(player, isNotNull);
      expect(player!.playerTag, equals('QST-7249'));
      expect(player.name, equals('Rohan Scout'));
    });

    test('3. Search for non-existent player 99999 returns null immediately without generating fake mock', () async {
      final stopwatch = Stopwatch()..start();
      final player = await friendsRepo.searchPlayer('99999');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3500));
      expect(player, isNull);
    });

    test('4. Searching for own player tag throws self-search exception', () async {
      final myTag = await friendsRepo.getMyPlayerTag();
      expect(
        () async => await friendsRepo.searchPlayer(myTag),
        throwsA(isA<AppException>().having(
          (e) => e.toString().toLowerCase(),
          'message',
          contains('own player id'),
        )),
      );
    });

    test('5. Registry does NOT contain fake dummy accounts (comp_1...comp_5)', () async {
      final registry = await localDataSource.getPlayerRegistry();
      for (final p in registry) {
        expect(p.userId.startsWith('comp_'), isFalse);
        expect(p.userId.startsWith('player_QST-'), isFalse);
      }
    });
  });
}
