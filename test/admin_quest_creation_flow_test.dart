import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:quest_up/core/services/activity_quest_catalog_service.dart';
import 'package:quest_up/core/services/places_discovery_service.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/models/quest_model.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';

class _AllowRealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowRealHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Admin newly created quest in localhost MySQL appears immediately in Flutter app', () async {
    final localSource = QuestLocalDataSource(
      LocalStorageService(),
      PlacesDiscoveryService(),
      ActivityQuestCatalogService(),
    );
    final mySqlSource = QuestMySqlDataSource();

    final repository = QuestRepositoryImpl(
      localDataSource: localSource,
      mySqlDataSource: mySqlSource,
    );

    // 1. Simulate Admin Creating a New Quest in Admin Panel
    final uniqueQuestId = 'admin_quest_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
    final adminCreatedQuest = QuestModel(
      id: uniqueQuestId,
      title: 'Admin Headquarters Landmark Expedition',
      description: 'Discover the secret landmark coordinates added via admin panel on localhost.',
      storyline: 'Explore the newly deployed admin mission.',
      category: QuestCategory.location,
      difficulty: QuestDifficulty.hard,
      verificationType: QuestVerificationType.photoProof,
      latitude: 12.9750,
      longitude: 77.5980,
      locationName: 'Admin Headquarters Landmark',
      radiusMeters: 100,
      xpReward: 450,
      coinReward: 200,
      requiredLevel: 1,
      isActive: true,
      requirements: const [
        QuestRequirement(
          title: 'Reach Location',
          description: 'Within 100m of landmark',
        ),
      ],
      iconKey: 'landmark',
    );

    try {
      // 2. Persist to MySQL database table `quests`
      await mySqlSource.saveQuestToMySql(adminCreatedQuest);

      // 3. Flutter app fetches quests (merges local + live MySQL)
      final appQuests = await repository.getQuests();

      // 4. Verify the newly created admin quest is present in the app!
      final foundQuest = appQuests.where((q) => q.id == uniqueQuestId).firstOrNull;
      expect(foundQuest, isNotNull, reason: 'Admin-created quest must appear in Flutter app quest list');
      expect(foundQuest!.title, equals('Admin Headquarters Landmark Expedition'));
      expect(foundQuest.xpReward, equals(450));
      expect(foundQuest.coinReward, equals(200));
      expect(foundQuest.locationName, equals('Admin Headquarters Landmark'));

      // 5. Verify opening the quest via getQuestById succeeds (fixing "Quest Not Found" bug)
      final openedQuest = await repository.getQuestById(uniqueQuestId);
      expect(openedQuest, isNotNull, reason: 'Opening the newly created quest must return the quest and not Quest Not Found');
      expect(openedQuest!.id, equals(uniqueQuestId));
      expect(openedQuest.title, equals('Admin Headquarters Landmark Expedition'));

      // 6. Verify nearby quests list (Home Radar) also contains the admin quest
      final nearbyQuests = await repository.getNearbyQuests(
        userLat: 12.9716,
        userLon: 77.5946,
      );
      final foundInRadar = nearbyQuests.where((q) => q.id == uniqueQuestId).firstOrNull;
      expect(foundInRadar, isNotNull, reason: 'Admin-created quest must appear on the Home Radar & Quests tab');
    } finally {
      // Clean up test quest from MySQL
      try {
        await mySqlSource.saveQuestToMySql(QuestModel.fromEntity(adminCreatedQuest.copyWith(isActive: false)));
      } catch (_) {}
    }
  });
}
