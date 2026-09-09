import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/models/quest_model.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/services/validators/gps_verifier.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

class MockTestLocalDataSource implements IQuestLocalDataSource {
  List<QuestModel> cached = [];

  @override
  Future<List<QuestModel>> getQuests() async => cached;

  @override
  Future<List<QuestModel>> getQuestsForLocation(
    double lat,
    double lon, {
    double maxRadiusMeters = 50000,
  }) async => cached;

  @override
  Future<void> saveQuests(List<QuestModel> quests) async {
    cached = List.from(quests);
  }

  @override
  Future<QuestModel?> getQuestById(String id) async {
    return cached.where((q) => q.id == id).firstOrNull;
  }

  @override
  Future<void> markCompleted(String id) async {}

  @override
  Future<List<Map<String, dynamic>>> getLocalSharedQuests() async => [];

  @override
  Future<void> saveLocalSharedQuests(List<Map<String, dynamic>> sharedQuests) async {}
}

class MockLocationTestMySqlDataSource implements IQuestMySqlDataSource {
  final List<QuestModel> adminQuests;
  final Map<String, List<QuestModel>> generatedByCity = {};

  MockLocationTestMySqlDataSource({required this.adminQuests});

  @override
  Future<List<QuestModel>> generateLocationQuests({
    required double latitude,
    required double longitude,
    String? userId,
    int? radiusMeters,
  }) async {
    // Shivamogga coordinates approx ~13.93, 75.56
    if ((latitude - 13.93).abs() < 0.2 && (longitude - 75.57).abs() < 0.2) {
      final shivamoggaQuests = List<QuestModel>.generate(
        6,
        (i) => QuestModel(
          id: 'gen_smg_$i',
          title: 'Shivamogga Landmark #$i Quest',
          description: 'Explore historical landmark in Shivamogga #$i',
          storyline: 'Uncover the heritage of Malnad in Shivamogga.',
          category: QuestCategory.location,
          latitude: 13.9300 + (i * 0.005),
          longitude: 75.5700 + (i * 0.005),
          radiusMeters: 100.0,
          xpReward: 150,
          coinReward: 75,
          requiredLevel: 1,
          requirements: const [
            QuestRequirement(
              title: 'Visit landmark',
              description: 'Reach the landmark in person',
            ),
          ],
          iconKey: 'landmark',
          locationName: 'Shivamogga Heritage Site #$i',
          difficulty: QuestDifficulty.medium,
          sourceType: 'location_generated',
          userId: userId,
          generationLatitude: latitude,
          generationLongitude: longitude,
        ),
      );
      generatedByCity['shivamogga'] = shivamoggaQuests;
      return shivamoggaQuests;
    }

    // Bengaluru coordinates approx ~12.97, 77.59
    if ((latitude - 12.97).abs() < 0.2 && (longitude - 77.59).abs() < 0.2) {
      final blrQuests = List<QuestModel>.generate(
        6,
        (i) => QuestModel(
          id: 'gen_blr_$i',
          title: 'Bengaluru Tech/Garden Landmark #$i Quest',
          description: 'Explore famous landmark in Bengaluru #$i',
          storyline: 'Explore the vibrant garden city of Bengaluru.',
          category: QuestCategory.location,
          latitude: 12.9716 + (i * 0.004),
          longitude: 77.5946 + (i * 0.004),
          radiusMeters: 100.0,
          xpReward: 180,
          coinReward: 90,
          requiredLevel: 1,
          requirements: const [
            QuestRequirement(
              title: 'Visit landmark',
              description: 'Reach the landmark in person',
            ),
          ],
          iconKey: 'landmark',
          locationName: 'Bengaluru Iconic Spot #$i',
          difficulty: QuestDifficulty.hard,
          sourceType: 'location_generated',
          userId: userId,
          generationLatitude: latitude,
          generationLongitude: longitude,
        ),
      );
      generatedByCity['bengaluru'] = blrQuests;
      return blrQuests;
    }

    return [];
  }

  @override
  Future<List<QuestModel>> fetchQuestsFromMySql({
    String? userId,
    double? userLat,
    double? userLon,
  }) async {
    final all = <QuestModel>[...adminQuests];
    for (final list in generatedByCity.values) {
      all.addAll(list);
    }
    return all;
  }

  @override
  Future<void> saveQuestToMySql(QuestModel quest) async {}
  @override
  Future<bool> saveCompletionToMySql(dynamic completion) async => true;
  @override
  Future<bool> isQuestCompletedByUserInMySql(String questId, String userId) async => false;
  @override
  Future<bool> shareQuestWithFriend({
    required String questId,
    required String questTitle,
    required String senderId,
    required String senderName,
    required String senderTag,
    required String receiverId,
  }) async => true;
  @override
  Future<List<Map<String, dynamic>>> fetchSharedQuests(String userId) async => [];
}

void main() {
  group('QuestUP Location-Based Dynamic Quest System Tests', () {
    const adminQuest = QuestModel(
      id: 'admin_supplementary_01',
      title: 'Admin Created Cultural Heritage Quest',
      description: 'Handcrafted admin quest available statewide.',
      storyline: 'Statewide cultural mission designed by admins.',
      category: QuestCategory.culture,
      latitude: 13.0000,
      longitude: 76.0000,
      radiusMeters: 150.0,
      xpReward: 300,
      coinReward: 150,
      requiredLevel: 1,
      requirements: [
        QuestRequirement(
          title: 'Statewide exploration',
          description: 'Explore Karnataka culture',
        ),
      ],
      iconKey: 'museum',
      locationName: 'Karnataka Heritage Center',
      difficulty: QuestDifficulty.medium,
      sourceType: 'admin',
    );

    test('User A logs in from Shivamogga -> gets Shivamogga landmark quests + admin quest', () async {
      final localSource = MockTestLocalDataSource();
      final mySqlSource = MockLocationTestMySqlDataSource(adminQuests: [adminQuest]);
      final repo = QuestRepositoryImpl(
        localDataSource: localSource,
        mySqlDataSource: mySqlSource,
      );

      // Shivamogga coordinates
      const userALat = 13.9299;
      const userALon = 75.5681;
      const userAId = 'user_shivamogga_A';

      final quests = await repo.getQuests(
        userLat: userALat,
        userLon: userALon,
        userId: userAId,
      );

      // Verify generated quests exist
      final generatedQuests = quests.where((q) => q.sourceType == 'location_generated').toList();
      final adminQuests = quests.where((q) => q.sourceType == 'admin').toList();

      expect(generatedQuests.length, equals(6));
      expect(adminQuests.length, equals(1));
      expect(quests.length, equals(7));

      // Shivamogga quests must have Shivamogga coordinates & names
      for (final q in generatedQuests) {
        expect(q.locationName, contains('Shivamogga'));
        expect((q.latitude - 13.93).abs(), lessThan(0.1));
        expect((q.longitude - 75.57).abs(), lessThan(0.1));
        expect(q.userId, equals(userAId));
        // Distance should be calculated and sorted nearest first
        expect(q.distanceMeters, isNotNull);
      }
    });

    test('User B logs in from Bengaluru -> gets distinct Bengaluru landmark quests + admin quest', () async {
      final localSource = MockTestLocalDataSource();
      final mySqlSource = MockLocationTestMySqlDataSource(adminQuests: [adminQuest]);
      final repo = QuestRepositoryImpl(
        localDataSource: localSource,
        mySqlDataSource: mySqlSource,
      );

      // Bengaluru coordinates
      const userBLat = 12.9716;
      const userBLon = 77.5946;
      const userBId = 'user_bengaluru_B';

      final quests = await repo.getQuests(
        userLat: userBLat,
        userLon: userBLon,
        userId: userBId,
      );

      final generatedQuests = quests.where((q) => q.sourceType == 'location_generated').toList();
      final adminQuests = quests.where((q) => q.sourceType == 'admin').toList();

      expect(generatedQuests.length, equals(6));
      expect(adminQuests.length, equals(1));
      expect(quests.length, equals(7));

      // Bengaluru quests must have Bengaluru coordinates & names
      for (final q in generatedQuests) {
        expect(q.locationName, contains('Bengaluru'));
        expect((q.latitude - 12.97).abs(), lessThan(0.1));
        expect((q.longitude - 77.59).abs(), lessThan(0.1));
        expect(q.userId, equals(userBId));
      }
    });

    test('Arrival Verification: GpsVerifier confirms arrival when distance <= radiusMeters', () async {
      final verifier = GpsVerifier();
      const destinationQuest = Quest(
        id: 'dest_test_01',
        title: 'Shivamogga City Clock Tower',
        description: 'Reach the central clock tower',
        storyline: 'Navigate to the historic clock tower in Shivamogga.',
        category: QuestCategory.location,
        difficulty: QuestDifficulty.easy,
        locationName: 'Shivamogga Clock Tower',
        latitude: 13.9299,
        longitude: 75.5681,
        radiusMeters: 100.0,
        xpReward: 100,
        coinReward: 50,
        requiredLevel: 1,
        requirements: [
          QuestRequirement(
            title: 'Reach destination',
            description: 'Stand within 100m of the clock tower',
          ),
        ],
        iconKey: 'landmark',
        sourceType: 'location_generated',
      );

      final attempt = QuestAttempt(
        attemptId: 'att_01',
        userId: 'user_A',
        questId: destinationQuest.id,
        startedAt: DateTime.now(),
      );

      // Case 1: User is 25 meters away (inside 100m radius) -> Destination Reached!
      final insidePayload = VerificationProofPayload(
        userLat: 13.9300,
        userLon: 75.5682,
      );

      final insideResult = await verifier.validate(
        quest: destinationQuest,
        attempt: attempt,
        payload: insidePayload,
      );

      expect(insideResult.passed, isTrue);
      expect(insideResult.message, contains('GPS Geofence Verified'));

      // Case 2: User is 3500 meters away (outside 100m radius) -> Blocked
      final outsidePayload = VerificationProofPayload(
        userLat: 13.9600,
        userLon: 75.5900,
      );

      final outsideResult = await verifier.validate(
        quest: destinationQuest,
        attempt: attempt,
        payload: outsidePayload,
      );

      expect(outsideResult.passed, isFalse);
      expect(outsideResult.message, contains('GPS Proximity Check Failed'));
    });

    test('TEST 3: Global Admin Quest appears identically for Shivamogga, Bengaluru, Mysuru, and Mangaluru players', () async {
      const globalAdminQuest = QuestModel(
        id: 'admin_global_jog_falls',
        title: 'GLOBAL ADMIN TEST QUEST: Visit Jog Falls',
        description: 'Explore Jog Falls, the majestic waterfall in Karnataka.',
        storyline: 'A statewide quest open to all players.',
        category: QuestCategory.location,
        latitude: 14.2285,
        longitude: 74.8124,
        radiusMeters: 100.0,
        xpReward: 500,
        coinReward: 250,
        requiredLevel: 1,
        requirements: [
          QuestRequirement(
            title: 'Visit Jog Falls',
            description: 'Stand at the viewpoint',
          ),
        ],
        iconKey: 'waterfall',
        locationName: 'Jog Falls Viewpoint',
        difficulty: QuestDifficulty.hard,
        sourceType: 'admin',
      );

      final localSource = MockTestLocalDataSource();
      final mySqlSource = MockLocationTestMySqlDataSource(adminQuests: [globalAdminQuest]);
      final repo = QuestRepositoryImpl(
        localDataSource: localSource,
        mySqlDataSource: mySqlSource,
      );

      // 1. Shivamogga player
      final shivamoggaQuests = await repo.getQuests(
        userLat: 13.9299,
        userLon: 75.5681,
        userId: 'user_smg',
      );
      final smgAdminQuest = shivamoggaQuests.where((q) => q.id == 'admin_global_jog_falls').firstOrNull;
      expect(smgAdminQuest, isNotNull);
      expect(smgAdminQuest!.sourceType, equals('admin'));

      // 2. Bengaluru player
      final bengaluruQuests = await repo.getQuests(
        userLat: 12.9716,
        userLon: 77.5946,
        userId: 'user_blr',
      );
      final blrAdminQuest = bengaluruQuests.where((q) => q.id == 'admin_global_jog_falls').firstOrNull;
      expect(blrAdminQuest, isNotNull);
      expect(blrAdminQuest!.sourceType, equals('admin'));
      expect(blrAdminQuest.title, equals(smgAdminQuest.title));

      // 3. Mysuru player
      final mysuruQuests = await repo.getQuests(
        userLat: 12.2958,
        userLon: 76.6394,
        userId: 'user_mysuru',
      );
      final mysAdminQuest = mysuruQuests.where((q) => q.id == 'admin_global_jog_falls').firstOrNull;
      expect(mysAdminQuest, isNotNull);
      expect(mysAdminQuest!.title, equals('GLOBAL ADMIN TEST QUEST: Visit Jog Falls'));

      // 4. Mangaluru player
      final mangaluruQuests = await repo.getQuests(
        userLat: 12.9141,
        userLon: 74.8560,
        userId: 'user_mangaluru',
      );
      final mngAdminQuest = mangaluruQuests.where((q) => q.id == 'admin_global_jog_falls').firstOrNull;
      expect(mngAdminQuest, isNotNull);
      expect(mngAdminQuest!.title, equals('GLOBAL ADMIN TEST QUEST: Visit Jog Falls'));
    });

    test('TEST 4: Global Admin Quest requires player to physically reach destination coordinates for arrival', () async {
      final verifier = GpsVerifier();
      const jogFallsAdminQuest = Quest(
        id: 'admin_global_jog_falls',
        title: 'GLOBAL ADMIN TEST QUEST: Visit Jog Falls',
        description: 'Explore Jog Falls',
        storyline: 'Statewide challenge.',
        category: QuestCategory.location,
        difficulty: QuestDifficulty.hard,
        locationName: 'Jog Falls Viewpoint',
        latitude: 14.2285,
        longitude: 74.8124,
        radiusMeters: 100.0,
        xpReward: 500,
        coinReward: 250,
        requiredLevel: 1,
        requirements: [
          QuestRequirement(
            title: 'Visit Jog Falls',
            description: 'Stand within 100m of Jog Falls viewpoint',
          ),
        ],
        iconKey: 'waterfall',
        sourceType: 'admin',
      );

      final attempt = QuestAttempt(
        attemptId: 'att_global_01',
        userId: 'player_in_karnataka',
        questId: jogFallsAdminQuest.id,
        startedAt: DateTime.now(),
      );

      // Player in Bengaluru (350 km away) -> GPS Proximity Fails
      final bengaluruPayload = VerificationProofPayload(
        userLat: 12.9716,
        userLon: 77.5946,
      );
      final blrResult = await verifier.validate(
        quest: jogFallsAdminQuest,
        attempt: attempt,
        payload: bengaluruPayload,
      );
      expect(blrResult.passed, isFalse);
      expect(blrResult.message, contains('GPS Proximity Check Failed'));

      // Player reaches Jog Falls (within 40m of viewpoint) -> Destination Reached!
      final onSitePayload = VerificationProofPayload(
        userLat: 14.2287,
        userLon: 74.8126,
      );
      final onSiteResult = await verifier.validate(
        quest: jogFallsAdminQuest,
        attempt: attempt,
        payload: onSitePayload,
      );
      expect(onSiteResult.passed, isTrue);
      expect(onSiteResult.message, contains('GPS Geofence Verified'));
    });

    test('DistanceCalculator calculates accurate Haversine distance in meters', () {
      final dist = DistanceCalculator.calculateDistanceMeters(
        lat1: 13.9299,
        lon1: 75.5681,
        lat2: 13.9309,
        lon2: 75.5691,
      );
      expect(dist, greaterThan(100));
      expect(dist, lessThan(200));
    });
  });
}
