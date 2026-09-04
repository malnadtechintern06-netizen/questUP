import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/achievements/data/datasources/achievement_local_datasource.dart';
import 'package:quest_up/features/achievements/data/models/achievement_model.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/calendar/data/datasources/quest_calendar_local_datasource.dart';
import 'package:quest_up/features/calendar/data/models/quest_calendar_entry_model.dart';
import 'package:quest_up/features/calendar/domain/entities/quest_calendar_entry.dart';
import 'package:quest_up/features/friends/data/datasources/friends_local_datasource.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/profile/data/datasources/user_local_datasource.dart';
import 'package:quest_up/features/profile/data/models/user_profile_model.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';
import 'package:quest_up/features/verification/data/models/quest_completion_model.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';

class MockMemoryStorage implements ILocalStorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<dynamic> getJson(String key) async => _data[key];

  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> saveJson(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> saveString(String key, String value) async => _data[key] = value;
}

void main() {
  group('Multi-Account Data Isolation Tests', () {
    late MockMemoryStorage storage;
    late AuthMySqlDataSource authDataSource;
    late UserLocalDataSource userLocalDataSource;
    late QuestLocalDataSource questLocalDataSource;
    late QuestCalendarLocalDataSource calendarLocalDataSource;
    late AchievementLocalDataSource achievementLocalDataSource;
    late VerificationLocalDataSource verificationLocalDataSource;
    late FriendsLocalDataSource friendsLocalDataSource;

    setUp(() {
      storage = MockMemoryStorage();
      authDataSource = AuthMySqlDataSource(storage);
      userLocalDataSource = UserLocalDataSource(storage);
      questLocalDataSource = QuestLocalDataSource(storage);
      calendarLocalDataSource = QuestCalendarLocalDataSource(storage);
      achievementLocalDataSource = AchievementLocalDataSource(storage);
      verificationLocalDataSource = VerificationLocalDataSource(storage);
      friendsLocalDataSource = FriendsLocalDataSource(storage);
    });

    test('Full multi-account lifecycle isolates quest status, XP, coins, calendar, achievements, and proofs', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final emailA = 'alice_$ts@adventure.com';
      final emailB = 'charlie_$ts@adventure.com';

      // -------------------------------------------------------------
      // 1. Register & Login User A (Alice)
      // -------------------------------------------------------------
      final userA = await authDataSource.register(
        name: 'Alice Pioneer',
        email: emailA,
        password: 'Password123!',
      );
      expect(userA.email, emailA);

      // User A initial profile
      var profileA = await userLocalDataSource.getUserProfile(userA.id);
      expect(profileA.name, 'Alice Pioneer');
      expect(profileA.currentXp, 0);
      expect(profileA.coins, 100);
      expect(profileA.completedQuestIds, isEmpty);

      // User A completes 2 quests and earns rewards
      final updatedProfileA = UserProfileModel.fromEntity(profileA.copyWith(
        currentXp: 350,
        coins: 240,
        level: 2,
        completedQuestIds: ['quest_landmark_1', 'quest_art_2'],
      ));
      await userLocalDataSource.saveUserProfile(updatedProfileA);

      // User A completes a quest in QuestLocalDataSource
      await questLocalDataSource.markCompleted('quest_landmark_1');

      // User A logs a calendar activity entry
      await calendarLocalDataSource.saveEntry(
        QuestCalendarEntryModel(
          id: 'cal_entry_1',
          questId: 'quest_landmark_1',
          questTitle: 'Ancient Monument Exploration',
          category: 'Landmark',
          difficulty: 'Medium',
          status: QuestActivityStatus.completed,
          timestamp: DateTime.now(),
          xpReward: 200,
          coinReward: 80,
        ),
      );

      // User A unlocks an achievement
      final achievementsA = await achievementLocalDataSource.getAchievements(userA.id);
      final updatedAchievementsA = achievementsA.map((a) {
        if (a.id == 'badge_first_quest') {
          return a.copyWith(isUnlocked: true, unlockedAt: DateTime.now());
        }
        return a;
      }).map((a) => AchievementModel.fromEntity(a)).toList();
      await achievementLocalDataSource.saveAchievements(updatedAchievementsA);

      // User A saves a verification completion
      await verificationLocalDataSource.saveCompletion(
        QuestCompletionModel(
          id: 'comp_user_a_1',
          questId: 'quest_landmark_1',
          userId: userA.id,
          completedAt: DateTime.now(),
          userLatitude: 12.9716,
          userLongitude: 77.5946,
          photoProofPath: 'proof_a.jpg',
          status: VerificationStatus.verified,
          xpEarned: 200,
          coinsEarned: 80,
        ),
      );

      // User A adds a custom friend
      final friendsA = await friendsLocalDataSource.getFriends();
      friendsA.add(
        FriendProfileModel(
          userId: 'friend_alice_1',
          playerTag: 'QST-9999',
          name: 'Bob Explorer',
          avatarKey: 'avatar_ranger',
          level: 3,
          currentXp: 1200,
          coins: 500,
          rank: 2,
          rankTitle: 'Scout',
          completedQuestsCount: 5,
          gamesPlayedCount: 5,
          completedQuests: const [],
          earnedBadges: const [],
          friendshipDate: DateTime.now(),
          isOnline: true,
          lastActiveText: 'Online',
        ),
      );
      await friendsLocalDataSource.saveFriends(friendsA);

      // Verify User A has active progress
      final reloadedQuestsA = await questLocalDataSource.getQuests();
      final q1ForA = reloadedQuestsA.where((q) => q.id == 'quest_landmark_1').firstOrNull;
      if (q1ForA != null) {
        expect(q1ForA.isCompleted, isTrue);
      }

      final reloadedCalendarA = await calendarLocalDataSource.getAllEntries(userA.id);
      expect(reloadedCalendarA.length, 1);

      final reloadedCompletionsA = await verificationLocalDataSource.getCompletions(userA.id);
      expect(reloadedCompletionsA.length, 1);

      // -------------------------------------------------------------
      // 2. User A Logs Out
      // -------------------------------------------------------------
      await authDataSource.logout();
      expect(await authDataSource.getCurrentUser(), isNull);

      // -------------------------------------------------------------
      // 3. User B (Charlie) Registers & Logs In
      // -------------------------------------------------------------
      final userB = await authDataSource.register(
        name: 'Charlie Newbie',
        email: emailB,
        password: 'Password456!',
      );
      expect(userB.email, emailB);

      // CRITICAL ASSERTION: User B MUST start with 100% clean profile
      final profileB = await userLocalDataSource.getUserProfile(userB.id);
      expect(profileB.id, userB.id);
      expect(profileB.name, 'Charlie Newbie');
      expect(profileB.email, emailB);
      expect(profileB.currentXp, 0, reason: "User B must have 0 XP");
      expect(profileB.coins, 100, reason: "User B starts with default starter coins");
      expect(profileB.level, 1, reason: "User B must start at Level 1");
      expect(profileB.completedQuestIds, isEmpty, reason: "User B must have 0 completed quests");

      // CRITICAL ASSERTION: Quests for User B must NOT show User A's completions
      final questsForB = await questLocalDataSource.getQuests();
      for (final q in questsForB) {
        expect(q.isCompleted, isFalse, reason: "Quest ${q.id} must be incomplete for new user B");
      }

      // CRITICAL ASSERTION: Calendar history for User B must be empty
      final calendarForB = await calendarLocalDataSource.getAllEntries(userB.id);
      expect(calendarForB, isEmpty, reason: "User B must have 0 calendar entries");

      // CRITICAL ASSERTION: Verifications for User B must be empty
      final completionsForB = await verificationLocalDataSource.getCompletions(userB.id);
      expect(completionsForB, isEmpty, reason: "User B must have 0 quest completions");

      // CRITICAL ASSERTION: Achievements for User B must be fresh (only starter badge)
      final achievementsForB = await achievementLocalDataSource.getAchievements(userB.id);
      final unlockedForB = achievementsForB.where((a) => a.isUnlocked).toList();
      expect(unlockedForB.length, 1);
      expect(unlockedForB.first.id, 'badge_first_step');

      // CRITICAL ASSERTION: User B's friends list does NOT contain User A's friend
      final friendsForB = await friendsLocalDataSource.getFriends();
      expect(friendsForB.any((f) => f.userId == 'friend_alice_1'), isFalse);

      // -------------------------------------------------------------
      // 4. User B completes a different quest
      // -------------------------------------------------------------
      await questLocalDataSource.markCompleted('quest_different_b');
      final currentProfileB = await userLocalDataSource.getUserProfile(userB.id);
      final updatedProfileB = UserProfileModel.fromEntity(currentProfileB.copyWith(
        currentXp: 150,
        completedQuestIds: ['quest_different_b'],
      ));
      await userLocalDataSource.saveUserProfile(updatedProfileB);

      // -------------------------------------------------------------
      // 5. User B logs out and User A logs back in
      // -------------------------------------------------------------
      await authDataSource.logout();

      // Login Alice again
      final reLoginAlice = await authDataSource.login(
        email: emailA,
        password: 'Password123!',
      );
      expect(reLoginAlice.id, userA.id);

      // CRITICAL ASSERTION: User A's original progress is fully intact!
      final restoredProfileA = await userLocalDataSource.getUserProfile(userA.id);
      expect(restoredProfileA.name, 'Alice Pioneer');
      expect(restoredProfileA.currentXp, 350, reason: "User A's 350 XP must be preserved");
      expect(restoredProfileA.coins, 240, reason: "User A's 240 coins must be preserved");
      expect(restoredProfileA.level, 2, reason: "User A's Level 2 must be preserved");
      expect(restoredProfileA.completedQuestIds, contains('quest_landmark_1'));
      expect(restoredProfileA.completedQuestIds, isNot(contains('quest_different_b')));

      // Calendar for User A is preserved
      final restoredCalendarA = await calendarLocalDataSource.getAllEntries(userA.id);
      expect(restoredCalendarA.length, 1);
      expect(restoredCalendarA.first.questId, 'quest_landmark_1');

      // Completions for User A are preserved
      final restoredCompletionsA = await verificationLocalDataSource.getCompletions(userA.id);
      expect(restoredCompletionsA.length, 1);
      expect(restoredCompletionsA.first.id, 'comp_user_a_1');

      // Friends for User A are preserved
      final restoredFriendsA = await friendsLocalDataSource.getFriends();
      expect(restoredFriendsA.any((f) => f.userId == 'friend_alice_1'), isTrue);
    });
  });
}
