import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/app/config/mysql_config.dart';
import 'package:quest_up/core/services/mysql_database_service.dart';
import 'package:quest_up/features/profile/data/datasources/user_mysql_datasource.dart';
import 'package:quest_up/features/profile/data/models/user_profile_model.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/models/quest_model.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/data/models/quest_completion_model.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';

void main() {
  group('MySQL Direct Sync & Integration Tests', () {
    late MySqlDatabaseService dbService;
    late UserMySqlDataSource userMySqlDataSource;
    late QuestMySqlDataSource questMySqlDataSource;

    setUpAll(() async {
      // Connect to local MySQL
      dbService = MySqlDatabaseService(MySqlConfig.defaults());
      userMySqlDataSource = UserMySqlDataSource(dbService);
      questMySqlDataSource = QuestMySqlDataSource(dbService);
    });

    test('1. Connects to questup_db and initializes schema', () async {
      final connected = await dbService.connect();
      expect(connected, isTrue);
    });

    test('2. Saves a real Quest to MySQL quests table', () async {
      final quest = QuestModel(
        id: 'test_quest_integration_001',
        title: 'Central Park Exploratory Trail',
        description: 'Navigate to the heart of the park and scan the fountain waypoint.',
        storyline: 'A journey through scenic park paths.',
        category: QuestCategory.location,
        verificationType: QuestVerificationType.locationGps,
        difficulty: QuestDifficulty.medium,
        latitude: 12.971598,
        longitude: 77.594566,
        radiusMeters: 120.0,
        xpReward: 250,
        coinReward: 75,
        requiredLevel: 1,
        requirements: const [],
        iconKey: 'quest_pin',
        locationName: 'Central Park Fountain',
        placeCategory: 'park',
        photoUrl: 'assets/images/hero_poster.jpg',
        isActive: true,
      );

      await questMySqlDataSource.saveQuestToMySql(quest);
      final quests = await questMySqlDataSource.fetchQuestsFromMySql();
      expect(quests.any((q) => q.id == 'test_quest_integration_001'), isTrue);
    });

    test('3. Registers User & Profile in MySQL', () async {
      final testUserId = 'test_user_integration_001';
      final testEmail = 'integration_hero@questup.com';

      // Insert test user
      await dbService.execute(
        '''
        INSERT INTO users (id, name, email, password_hash, salt, status, created_at)
        VALUES (:id, 'Integration Hero', :email, 'hash123', 'salt123', 'active', NOW())
        ON DUPLICATE KEY UPDATE name = 'Integration Hero'
        ''',
        {'id': testUserId, 'email': testEmail},
      );

      final profile = UserProfileModel(
        id: testUserId,
        name: 'Integration Hero',
        email: testEmail,
        avatarKey: 'avatar_ranger',
        level: 2,
        currentXp: 350,
        xpToNextLevel: 650,
        coins: 200,
        completedQuestIds: const [],
        earnedBadgeIds: const ['badge_first_step'],
        joinedAt: DateTime.now(),
      );

      await userMySqlDataSource.saveProfileToMySql(profile);
      final fetched = await userMySqlDataSource.fetchProfileFromMySql(testUserId);
      expect(fetched, isNotNull);
      expect(fetched!.level, 2);
      expect(fetched.currentXp, 350);
      expect(fetched.coins, 200);
    });

    test('4. Completes Quest, saves completion to quest_completions, and updates profile stats in MySQL', () async {
      final testUserId = 'test_user_integration_001';
      final testQuestId = 'test_quest_integration_001';

      final completion = QuestCompletionModel(
        id: 'test_completion_integration_001',
        questId: testQuestId,
        userId: testUserId,
        completedAt: DateTime.now(),
        userLatitude: 12.971598,
        userLongitude: 77.594566,
        photoProofPath: 'smart_proof_verified',
        status: VerificationStatus.verified,
        xpEarned: 250,
        coinsEarned: 75,
      );

      // Save completion
      final saved = await questMySqlDataSource.saveCompletionToMySql(completion);
      expect(saved, isTrue);

      // Duplicate protection check
      final isDup = await questMySqlDataSource.isQuestCompletedByUserInMySql(testQuestId, testUserId);
      expect(isDup, isTrue);

      // Update user profile stats
      await userMySqlDataSource.updateXpAndCoinsInMySql(
        userId: testUserId,
        level: 3,
        currentXp: 600,
        xpToNextLevel: 800,
        coins: 275,
      );

      final updatedProfile = await userMySqlDataSource.fetchProfileFromMySql(testUserId);
      expect(updatedProfile, isNotNull);
      expect(updatedProfile!.level, 3);
      expect(updatedProfile.currentXp, 600);
      expect(updatedProfile.coins, 275);
    });
  });
}
