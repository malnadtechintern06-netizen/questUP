import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/auth/data/models/auth_user_model.dart';
import 'package:quest_up/features/profile/data/models/user_profile_model.dart';
import 'package:quest_up/features/profile/data/repositories/user_repository_impl.dart';
import 'package:quest_up/core/services/google_place_photo_service.dart';
import 'package:quest_up/features/profile/data/datasources/user_local_datasource.dart';
import 'package:quest_up/features/verification/domain/services/scene_authenticity_service.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/models/quest_model.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/utils/quest_image_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quest_up/core/services/location_service.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/location_permission/presentation/providers/location_permission_provider.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/achievements/data/datasources/achievement_local_datasource.dart';
import 'package:quest_up/features/achievements/data/repositories/achievement_repository_impl.dart';
import 'package:quest_up/features/calendar/domain/entities/quest_calendar_entry.dart';
import 'package:quest_up/features/calendar/data/datasources/quest_calendar_local_datasource.dart';
import 'package:quest_up/features/calendar/data/repositories/quest_calendar_repository_impl.dart';
import 'package:quest_up/features/calendar/presentation/providers/quest_calendar_providers.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/services/duplicate_proof_service.dart';
import 'package:quest_up/features/verification/domain/services/quest_verification_service.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';
import 'package:quest_up/features/verification/data/repositories/verification_repository_impl.dart';

class MockUserLocalDataSource implements IUserLocalDataSource {
  UserProfileModel profile;

  MockUserLocalDataSource(this.profile);

  @override
  Future<UserProfileModel> getUserProfile() async => profile;

  @override
  Future<void> saveUserProfile(UserProfileModel updated) async {
    profile = updated;
  }
}

class MockQuestLocalDataSource implements IQuestLocalDataSource {
  List<QuestModel> quests;

  MockQuestLocalDataSource(this.quests);

  @override
  Future<List<QuestModel>> getQuests() async => quests;

  @override
  Future<List<QuestModel>> getQuestsForLocation(
    double userLat,
    double userLon, {
    double maxRadiusMeters = 5000.0,
  }) async => quests;

  @override
  Future<void> saveQuests(List<QuestModel> newQuests) async {
    quests = newQuests;
  }

  @override
  Future<QuestModel?> getQuestById(String id) async {
    try {
      return quests.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markCompleted(String id) async {}
}

class MockQuestMySqlDataSource implements IQuestMySqlDataSource {
  @override
  Future<List<QuestModel>> fetchQuestsFromMySql() async => [];

  @override
  Future<void> saveQuestToMySql(QuestModel quest) async {}

  @override
  Future<void> markCompletedInMySql(String questId, String userId, {int xp = 0, int coins = 0}) async {}
}

void main() {
  group('DistanceCalculator Tests', () {
    test('Calculates Haversine distance between two coordinates accurately', () {
      final distance = DistanceCalculator.calculateDistanceMeters(
        lat1: 12.9716,
        lon1: 77.5946,
        lat2: 12.9720,
        lon2: 77.5950,
      );

      expect(distance, greaterThan(40));
      expect(distance, lessThan(80));
    });

    test('isWithinRadius checks geofence proximity correctly', () {
      final inRange = DistanceCalculator.isWithinRadius(
        userLat: 12.9716,
        userLon: 77.5946,
        targetLat: 12.9718,
        targetLon: 77.5948,
        radiusMeters: 75.0,
      );
      expect(inRange, isTrue);

      final outOfRange = DistanceCalculator.isWithinRadius(
        userLat: 12.9716,
        userLon: 77.5946,
        targetLat: 13.0100,
        targetLon: 77.6500,
        radiusMeters: 75.0,
      );
      expect(outOfRange, isFalse);
    });

    test('formatDistance formats meters and kilometers properly', () {
      expect(DistanceCalculator.formatDistance(45), '45 m');
      expect(DistanceCalculator.formatDistance(999), '999 m');
      expect(DistanceCalculator.formatDistance(1500), '1.5 km');
      expect(DistanceCalculator.formatDistance(12400), '12.4 km');
    });
  });

  group('Location-Based Quest Sorting & Filtering Tests', () {
    test('QuestRepositoryImpl calculates distance, filters by radius, and sorts closest first', () async {
      const userLat = 12.9716;
      const userLon = 77.5946;

      final questNear = QuestModel(
        id: 'q_near',
        title: 'Near Waypoint',
        description: 'Close waypoint',
        storyline: 'Close',
        category: QuestCategory.landmark,
        difficulty: QuestDifficulty.easy,
        latitude: 12.9720, // ~60m away
        longitude: 77.5950,
        locationName: 'Near',
        radiusMeters: 75.0,
        xpReward: 100,
        coinReward: 50,
        requiredLevel: 1,
        requirements: const [],
        iconKey: 'beacon',
      );

      final questFar = QuestModel(
        id: 'q_far',
        title: 'Far Waypoint',
        description: 'Distant waypoint',
        storyline: 'Distant',
        category: QuestCategory.mystery,
        difficulty: QuestDifficulty.hard,
        latitude: 12.9850, // ~1.8km away
        longitude: 77.6050,
        locationName: 'Far',
        radiusMeters: 100.0,
        xpReward: 300,
        coinReward: 150,
        requiredLevel: 1,
        requirements: const [],
        iconKey: 'mystery',
      );

      final questOutsideRadius = QuestModel(
        id: 'q_outside',
        title: 'Outside Waypoint',
        description: 'Outside 5km radius',
        storyline: 'Outside',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.legendary,
        latitude: 13.0800, // ~15km away
        longitude: 77.7000,
        locationName: 'Outside',
        radiusMeters: 150.0,
        xpReward: 500,
        coinReward: 250,
        requiredLevel: 1,
        requirements: const [],
        iconKey: 'nature',
      );

      final mockLocal = MockQuestLocalDataSource([questFar, questNear, questOutsideRadius]);
      final mockRemote = MockQuestMySqlDataSource();
      final repo = QuestRepositoryImpl(
        localDataSource: mockLocal,
        mySqlDataSource: mockRemote,
      );

      final nearbyQuests = await repo.getNearbyQuests(
        userLat: userLat,
        userLon: userLon,
        maxDistanceMeters: 5000,
      );

      expect(nearbyQuests.length, equals(2));
      expect(nearbyQuests.first.id, equals('q_near'));
      expect(nearbyQuests.first.distanceMeters, isNotNull);
      expect(nearbyQuests.first.distanceMeters!, lessThan(100));

      expect(nearbyQuests.last.id, equals('q_far'));
      expect(nearbyQuests.last.distanceMeters!, greaterThan(1000));
    });
  });

  group('User XP & Level Progression Tests', () {
    test('UserRepositoryImpl accurately awards XP, coins, and handles level up', () async {
      final initialProfile = UserProfileModel(
        id: 'test_user',
        name: 'Test Explorer',
        email: 'test@questup.com',
        avatarKey: 'avatar_ranger',
        level: 1,
        currentXp: 400,
        xpToNextLevel: AppConstants.baseLevelXp, // 500
        coins: 100,
        completedQuestIds: const [],
        earnedBadgeIds: const ['badge_first_step'],
        joinedAt: DateTime.now(),
      );

      final mockDs = MockUserLocalDataSource(initialProfile);
      final repository = UserRepositoryImpl(mockDs);

      final updated = await repository.addXpAndCoins(
        xp: 200,
        coins: 50,
        completedQuestId: 'quest_1',
      );

      expect(updated.level, equals(2));
      expect(updated.currentXp, equals(100));
      expect(updated.coins, equals(150));
      expect(updated.completedQuestIds, contains('quest_1'));
      expect(updated.xpToNextLevel, equals((500 * AppConstants.xpMultiplierPerLevel).round()));
    });
  });

  group('Auth Model Tests', () {
    test('AuthUserModel serializes and deserializes JSON correctly', () {
      final now = DateTime.now();
      final model = AuthUserModel(
        id: 'u_123',
        email: 'explorer@questup.com',
        displayName: 'Aria Silver',
        photoUrl: 'https://example.com/photo.jpg',
        isEmailVerified: true,
        createdAt: now,
      );

      final json = model.toJson();
      final deserialized = AuthUserModel.fromJson(json);

      expect(deserialized.id, equals('u_123'));
      expect(deserialized.email, equals('explorer@questup.com'));
      expect(deserialized.displayName, equals('Aria Silver'));
      expect(deserialized.isEmailVerified, isTrue);
    });
  });

  group('Universal Quest Verification Engine Tests', () {
    final engine = QuestVerificationService();

    test('Generic Object Detection verifies any requiredObject without hardcoding', () async {
      final attempt = QuestAttempt(
        attemptId: 'att_flower_1',
        userId: 'u_1',
        questId: 'q_flower',
        startedAt: DateTime.now(),
      );

      // Quest 1: Flower
      const flowerQuest = Quest(
        id: 'q_flower',
        title: 'Find a Flower',
        description: 'Snap a flower',
        storyline: 'Flora',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.easy,
        latitude: 0,
        longitude: 0,
        locationName: 'Garden',
        radiusMeters: 0,
        xpReward: 40,
        coinReward: 20,
        requiredLevel: 1,
        requiresFreshPhoto: true,
        requiredObject: 'flower',
        requirements: [],
        iconKey: 'nature',
      );

      final flowerReport = await engine.evaluateAttempt(
        quest: flowerQuest,
        attempt: attempt,
        payload: VerificationProofPayload(
          photoProofPath: 'camera_capture_flower_proof.jpg',
          isFreshCameraCapture: true,
          photoAttemptId: 'att_flower_1',
        ),
      );
      expect(flowerReport.isSuccessful, isTrue);
      expect(flowerReport.results.any((r) => r.validatorName == 'Object Detection' && r.passed), isTrue);

      // Quest 2: Cow
      const cowQuest = Quest(
        id: 'q_cow',
        title: 'Find a Cow',
        description: 'Snap a cow',
        storyline: 'Cattle',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.medium,
        latitude: 0,
        longitude: 0,
        locationName: 'Pasture',
        radiusMeters: 0,
        xpReward: 50,
        coinReward: 25,
        requiredLevel: 1,
        requiresFreshPhoto: true,
        requiredObject: 'cow',
        requirements: [],
        iconKey: 'nature',
      );

      final cowReport = await engine.evaluateAttempt(
        quest: cowQuest,
        attempt: attempt,
        payload: VerificationProofPayload(
          photoProofPath: 'camera_capture_cow_proof.jpg',
          isFreshCameraCapture: true,
          photoAttemptId: 'att_flower_1',
        ),
      );
      expect(cowReport.isSuccessful, isTrue);

      // Quest 3: Apple
      const appleQuest = Quest(
        id: 'q_apple',
        title: 'Photograph an Apple',
        description: 'Snap an apple',
        storyline: 'Fruit',
        category: QuestCategory.food,
        difficulty: QuestDifficulty.easy,
        latitude: 0,
        longitude: 0,
        locationName: 'Kitchen',
        radiusMeters: 0,
        xpReward: 35,
        coinReward: 15,
        requiredLevel: 1,
        requiresFreshPhoto: true,
        requiredObject: 'apple',
        requirements: [],
        iconKey: 'food',
      );

      final appleReport = await engine.evaluateAttempt(
        quest: appleQuest,
        attempt: attempt,
        payload: VerificationProofPayload(
          photoProofPath: 'camera_capture_apple_proof.jpg',
          isFreshCameraCapture: true,
          photoAttemptId: 'att_flower_1',
        ),
      );
      expect(appleReport.isSuccessful, isTrue);
    });

    test('Fresh Photo Verifier rejects gallery upload when requiresFreshPhoto is true', () async {
      final attempt = QuestAttempt(
        attemptId: 'att_fresh_strict',
        userId: 'u_1',
        questId: 'q_strict_tree',
        startedAt: DateTime.now(),
      );

      const treeQuest = Quest(
        id: 'q_strict_tree',
        title: 'Photograph a Tree',
        description: 'Live capture only',
        storyline: 'Tree',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.easy,
        latitude: 0,
        longitude: 0,
        locationName: 'Park',
        radiusMeters: 0,
        xpReward: 40,
        coinReward: 20,
        requiredLevel: 1,
        requiresFreshPhoto: true,
        requiredObject: 'tree',
        requirements: [],
        iconKey: 'nature',
      );

      // Gallery upload (not fresh capture) -> should fail
      final galleryReport = await engine.evaluateAttempt(
        quest: treeQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          photoProofPath: '/storage/emulated/0/DCIM/old_gallery_photo.jpg',
          isFreshCameraCapture: false,
        ),
      );
      expect(galleryReport.isSuccessful, isFalse);
      expect(galleryReport.results.any((r) => r.validatorName == 'Fresh In-App Photo Proof' && !r.passed), isTrue);

      // Live In-App Camera capture -> should pass
      final freshReport = await engine.evaluateAttempt(
        quest: treeQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          photoProofPath: 'camera_capture_tree_123.jpg',
          isFreshCameraCapture: true,
          photoAttemptId: 'att_fresh_strict',
        ),
      );
      expect(freshReport.isSuccessful, isTrue);
    });

    test('Composite Verification requires all sub-requirements to pass', () async {
      final attempt = QuestAttempt(
        attemptId: 'att_composite_1',
        userId: 'u_1',
        questId: 'q_composite',
        startedAt: DateTime.now(),
      );

      // Quest: Walk 500m AND Photograph a Tree
      const compositeQuest = Quest(
        id: 'q_composite',
        title: 'Walk 500m & Photograph a Tree',
        description: 'Combined challenge',
        storyline: 'Walk and find tree',
        category: QuestCategory.walking,
        difficulty: QuestDifficulty.medium,
        verificationType: QuestVerificationType.walkingGps,
        latitude: 0,
        longitude: 0,
        locationName: 'Trail',
        radiusMeters: 0,
        xpReward: 65,
        coinReward: 35,
        requiredLevel: 1,
        requiredDistanceMeters: 500,
        requiresGPS: true,
        requiresFreshPhoto: true,
        requiredObject: 'tree',
        requirements: [],
        iconKey: 'walking',
      );

      // Case A: Walked 550m, but no photo -> Fails
      final partialReport1 = await engine.evaluateAttempt(
        quest: compositeQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          distanceMeters: 550,
          isFreshCameraCapture: false,
        ),
      );
      expect(partialReport1.isSuccessful, isFalse);

      // Case B: Took photo, but only walked 200m -> Fails
      final partialReport2 = await engine.evaluateAttempt(
        quest: compositeQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          distanceMeters: 200,
          photoProofPath: 'camera_capture_tree_proof.jpg',
          isFreshCameraCapture: true,
          photoAttemptId: 'att_composite_1',
        ),
      );
      expect(partialReport2.isSuccessful, isFalse);

      // Case C: Walked 520m AND took fresh tree photo -> Passes all
      final completeReport = await engine.evaluateAttempt(
        quest: compositeQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          distanceMeters: 520,
          photoProofPath: 'camera_capture_tree_proof.jpg',
          isFreshCameraCapture: true,
          photoAttemptId: 'att_composite_1',
        ),
      );
      expect(completeReport.isSuccessful, isTrue);
      expect(completeReport.results.length, greaterThanOrEqualTo(2));
      expect(completeReport.results.every((r) => r.passed), isTrue);
    });

    test('Anti-Cheat Writing Verification detects and blocks copy-paste from ChatGPT and AI phrases', () async {
      final attempt = QuestAttempt(
        attemptId: 'att_writing_cheat_1',
        userId: 'u_1',
        questId: 'q_hometown_essay',
        startedAt: DateTime.now(),
      );

      const writingQuest = Quest(
        id: 'q_hometown_essay',
        title: 'Describe Your Hometown',
        description: 'Write 20 words about your hometown and favorite spot.',
        storyline: 'Creative Writing',
        category: QuestCategory.writing,
        difficulty: QuestDifficulty.easy,
        verificationType: QuestVerificationType.writingText,
        latitude: 0,
        longitude: 0,
        locationName: 'Home',
        radiusMeters: 0,
        xpReward: 50,
        coinReward: 25,
        requiredLevel: 1,
        requiredWords: 20,
        requirements: [],
        iconKey: 'writing',
      );

      // Case A: User copy-pasted a summary from ChatGPT or external notes -> Rejected
      final pastedReport = await engine.evaluateAttempt(
        quest: writingQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          textContent: 'My hometown is a beautiful valley surrounded by lush green hills, fresh streams, calm temples, and wonderful kind people.',
          wordCount: 20,
          isPasted: true,
          pastedCharactersCount: 130,
          isAuthenticallyTyped: false,
        ),
      );
      expect(pastedReport.isSuccessful, isFalse);
      expect(pastedReport.results.any((r) => r.validatorName == 'Originality & Anti-Cheat' && !r.passed), isTrue);

      // Case B: User typed AI chatbot prompt boilerplate -> Rejected
      final aiReport = await engine.evaluateAttempt(
        quest: writingQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          textContent: 'As an AI language model, here is a 20-word summary of a hometown with scenic hills, tranquil lakes, and welcoming communities everywhere.',
          wordCount: 22,
          isPasted: false,
          pastedCharactersCount: 0,
          isAuthenticallyTyped: true,
        ),
      );
      expect(aiReport.isSuccessful, isFalse);
      expect(aiReport.results.any((r) => r.validatorName == 'Originality & Anti-Cheat' && !r.passed), isTrue);

      // Case C: User repeated the same word 20 times (spam) -> Rejected
      final spamReport = await engine.evaluateAttempt(
        quest: writingQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          textContent: 'hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown hometown',
          wordCount: 20,
          isPasted: false,
          isAuthenticallyTyped: true,
        ),
      );
      expect(spamReport.isSuccessful, isFalse);
      expect(spamReport.results.any((r) => r.validatorName == 'Originality & Anti-Cheat' && !r.passed), isTrue);

      // Case D: User typed original authentic text directly -> Passed
      final authenticReport = await engine.evaluateAttempt(
        quest: writingQuest,
        attempt: attempt,
        payload: const VerificationProofPayload(
          textContent: 'I grew up near the riverbank where morning mist rolls over the fields and neighbors always greet each other with warm smiles.',
          wordCount: 22,
          isPasted: false,
          pastedCharactersCount: 0,
          isAuthenticallyTyped: true,
        ),
      );
      expect(authenticReport.isSuccessful, isTrue);
      expect(authenticReport.results.any((r) => r.validatorName == 'Originality & Anti-Cheat' && r.passed), isTrue);
      expect(authenticReport.results.any((r) => r.validatorName == 'Word Count Requirement' && r.passed), isTrue);
    });
  });

  group('QuestImageResolver Tests', () {
    test('Resolves distinct place-specific and category-specific photos without using app logo or hero banner', () {
      // 1. College landmark
      final collegeImg = QuestImageResolver.resolvePlaceCategoryImageUrl(
        specificCategory: 'college',
        placeName: 'Kodachadri Government First Grade College',
      );
      expect(collegeImg, isNotNull);
      expect(collegeImg, isNot(contains('hero_poster')));
      expect(collegeImg, isNot(contains('logo.png')));

      // 2. Temple landmark
      final templeImg = QuestImageResolver.resolvePlaceCategoryImageUrl(
        specificCategory: 'temple',
        placeName: 'Sri Mookambika Temple',
      );
      expect(templeImg, isNotNull);
      expect(templeImg, isNot(equals(collegeImg)));

      // 3. Waterfall landmark
      final waterfallImg = QuestImageResolver.resolvePlaceCategoryImageUrl(
        specificCategory: 'waterfall',
        placeName: 'Hidlumane Waterfalls',
      );
      expect(waterfallImg, isNotNull);
      expect(waterfallImg, isNot(equals(templeImg)));

      // 4. Park landmark
      final parkImg = QuestImageResolver.resolvePlaceCategoryImageUrl(
        specificCategory: 'park',
        placeName: 'National Reserve Park',
      );
      expect(parkImg, isNotNull);
      expect(parkImg, isNot(equals(waterfallImg)));
    });

    test('Resolves object-specific photos for photo quests dynamically', () {
      const flowerQuest = Quest(
        id: 'q_flower',
        title: 'Find a Flower',
        description: 'Snap flower',
        storyline: 'Nature',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.easy,
        latitude: 0,
        longitude: 0,
        locationName: 'Garden',
        radiusMeters: 0,
        xpReward: 40,
        coinReward: 20,
        requiredLevel: 1,
        requiredObject: 'flower',
        requirements: [],
        iconKey: 'nature',
      );

      const cowQuest = Quest(
        id: 'q_cow',
        title: 'Find a Cow',
        description: 'Snap cow',
        storyline: 'Pasture',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.medium,
        latitude: 0,
        longitude: 0,
        locationName: 'Farm',
        radiusMeters: 0,
        xpReward: 50,
        coinReward: 25,
        requiredLevel: 1,
        requiredObject: 'cow',
        requirements: [],
        iconKey: 'nature',
      );

      final flowerUrl = QuestImageResolver.resolveQuestImageUrl(flowerQuest);
      final cowUrl = QuestImageResolver.resolveQuestImageUrl(cowQuest);

      expect(flowerUrl, isNotEmpty);
      expect(cowUrl, isNotEmpty);
      expect(flowerUrl, isNot(equals(cowUrl)));
      expect(flowerUrl, isNot(contains('hero_poster')));
      expect(cowUrl, isNot(contains('hero_poster')));
    });

    test('Prioritizes exact Google Places photo URL for exact Place ID over category fallbacks', () {
      const exactHospitalQuest = Quest(
        id: 'gplace_ChIJf-Z-5gCEuzsRfsP2N31R1pw',
        placeId: 'ChIJf-Z-5gCEuzsRfsP2N31R1pw',
        placeCategory: 'hospital',
        placeAddress: 'Hosanagar, Karnataka 577418',
        placeTypes: ['hospital', 'health'],
        title: 'Visit Government Hospital',
        description: 'Explore the hospital',
        storyline: 'Hospital',
        category: QuestCategory.landmark,
        difficulty: QuestDifficulty.easy,
        latitude: 13.9182,
        longitude: 75.0682,
        locationName: 'Government Hospital',
        radiusMeters: 100,
        xpReward: 50,
        coinReward: 25,
        requiredLevel: 1,
        photoReference: 'AcJR_ExactGovHospitalPhotoRef123',
        photoReferences: ['AcJR_ExactGovHospitalPhotoRef123', 'AcJR_ExactGovHospitalPhotoRef456'],
        photoUrl: 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=AcJR_ExactGovHospitalPhotoRef123&key=TEST_KEY',
        imageSource: 'google_places',
        requirements: [],
        iconKey: 'landmark',
      );

      final resolvedUrl = QuestImageResolver.resolveQuestImageUrl(exactHospitalQuest);

      // Must be the exact photo belonging to that place, not generic unsplash image
      expect(resolvedUrl, equals('https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=AcJR_ExactGovHospitalPhotoRef123&key=TEST_KEY'));
      expect(exactHospitalQuest.isGooglePlacesPhoto, isTrue);
      expect(exactHospitalQuest.placeId, equals('ChIJf-Z-5gCEuzsRfsP2N31R1pw'));
    });

    test('QuestModel correctly serializes and deserializes placeId, photoReferences, and imageSource', () {
      const original = QuestModel(
        id: 'gplace_123',
        placeId: 'ChIJf-Z-5gCEuzsRfsP2N31R1pw',
        placeCategory: 'hospital',
        placeAddress: 'Hosanagar, Karnataka',
        placeTypes: ['hospital', 'health'],
        title: 'Government Hospital',
        description: 'Desc',
        storyline: 'Story',
        category: QuestCategory.landmark,
        difficulty: QuestDifficulty.easy,
        latitude: 13.91,
        longitude: 75.06,
        locationName: 'Government Hospital',
        radiusMeters: 100,
        xpReward: 50,
        coinReward: 25,
        requiredLevel: 1,
        photoReference: 'photo_ref_1',
        photoReferences: ['photo_ref_1', 'photo_ref_2'],
        photoUrl: 'https://maps.googleapis.com/photo?ref=photo_ref_1',
        imageSource: 'google_places',
        requirements: [],
        iconKey: 'landmark',
      );

      final json = original.toJson();
      expect(json['placeId'], equals('ChIJf-Z-5gCEuzsRfsP2N31R1pw'));
      expect(json['imageSource'], equals('google_places'));
      expect(json['photoReferences'], equals(['photo_ref_1', 'photo_ref_2']));

      final deserialized = QuestModel.fromJson(json);
      expect(deserialized.placeId, equals('ChIJf-Z-5gCEuzsRfsP2N31R1pw'));
      expect(deserialized.imageSource, equals('google_places'));
      expect(deserialized.photoReferences.length, equals(2));
      expect(deserialized.isGooglePlacesPhoto, isTrue);
    });
  });

  group('GooglePlacePhotoService Tests', () {
    test('Builds official Google Places Photo URL correctly when API key is present', () {
      final photoService = GooglePlacePhotoService();
      // If key is present or formatted, buildPhotoUrl returns official endpoint format
      final url = photoService.buildPhotoUrl('test_photo_ref_123', maxWidth: 800);
      if (AppConstants.googleMapsApiKey.isNotEmpty) {
        expect(url, contains('https://maps.googleapis.com/maps/api/place/photo'));
        expect(url, contains('test_photo_ref_123'));
        expect(url, contains('maxwidth=800'));
      } else {
        expect(url, isNull);
      }
    });
  });

  group('Hardcore Badges & Achievements Tests', () {
    test('AchievementLocalDataSource provides exactly 13 total badges including 7 extra hardcore badges', () async {
      final mockStorage = MockTestLocalStorageService();
      final dataSource = AchievementLocalDataSource(mockStorage);

      final badges = await dataSource.getAchievements();
      expect(badges.length, equals(13));

      final hardcoreBadges = badges.where((b) => b.isHardcore).toList();
      expect(hardcoreBadges.length, equals(7));

      final titles = hardcoreBadges.map((b) => b.title).toList();
      expect(titles, contains('Century Globetrotter'));
      expect(titles, contains("Dragon's Treasury"));
      expect(titles, contains('Iron Marathoner'));
      expect(titles, contains('Eagle Eye Spotter'));
      expect(titles, contains('Enigma Slayer'));
      expect(titles, contains('Apex Titan'));
      expect(titles, contains('Immortal Mythic'));
    });

    test('AchievementRepositoryImpl unlocks hardcore badges when hardcore thresholds are achieved', () async {
      final mockStorage = MockTestLocalStorageService();
      final dataSource = AchievementLocalDataSource(mockStorage);
      final repository = AchievementRepositoryImpl(dataSource);

      // 1. Initial evaluation with 0 quests, level 1, 0 coins -> No hardcore unlock
      final unl1 = await repository.evaluateAndUnlockAchievements(
        completedCount: 0,
        currentLevel: 1,
        totalCoins: 0,
      );
      expect(unl1?.isHardcore, isNot(true));

      // 2. Player completes 15 quests & reaches Level 3 -> Unlocks Century Globetrotter
      final unl2 = await repository.evaluateAndUnlockAchievements(
        completedCount: 15,
        currentLevel: 3,
        totalCoins: 500,
      );
      expect(unl2, isNotNull);
      expect(unl2!.id, equals('badge_grandmaster_explorer'));
      expect(unl2.title, equals('Century Globetrotter'));
      expect(unl2.isHardcore, isTrue);

      // 3. Player ascends to Level 5 -> Unlocks Apex Titan
      final unl3 = await repository.evaluateAndUnlockAchievements(
        completedCount: 15,
        currentLevel: 5,
        totalCoins: 1000,
      );
      expect(unl3, isNotNull);
      expect(unl3!.id, equals('badge_apex_predator'));
      expect(unl3.title, equals('Apex Titan'));
      expect(unl3.tier, equals('HARDCORE'));

      // 4. Player amasses 5000 coins & reaches Level 8 -> Unlocks Immortal Mythic
      final unl4 = await repository.evaluateAndUnlockAchievements(
        completedCount: 20,
        currentLevel: 8,
        totalCoins: 5000,
      );
      expect(unl4, isNotNull);
      expect(unl4!.id, equals('badge_immortal_legend'));
      expect(unl4.title, equals('Immortal Mythic'));
      expect(unl4.tier, equals('MYTHIC'));
    });
  });

  group('Quest Activity Calendar Tests', () {
    test('QuestCalendarRepository records and queries completed, failed, and incomplete quests accurately', () async {
      final mockStorage = MockTestLocalStorageService();
      final localDataSource = QuestCalendarLocalDataSource(mockStorage);
      final repository = QuestCalendarRepositoryImpl(localDataSource: localDataSource);

      final today = DateTime(2026, 9, 2);

      // 1. Record a completed quest
      await repository.recordQuestActivity(
        questId: 'q_test_1',
        questTitle: 'Visit City Park',
        category: 'Nature',
        status: QuestActivityStatus.completed,
        timestamp: today.add(const Duration(hours: 10)),
        xpReward: 100,
        coinReward: 50,
      );

      // 2. Record a failed quest with reason
      await repository.recordQuestActivity(
        questId: 'q_test_2',
        questTitle: 'High Altitude Peak',
        category: 'Fitness',
        status: QuestActivityStatus.failed,
        timestamp: today.add(const Duration(hours: 14)),
        failureReason: 'GPS distance exceeded geofence radius',
      );

      // 3. Record an incomplete quest
      await repository.recordQuestActivity(
        questId: 'q_test_3',
        questTitle: 'Write City Lore',
        category: 'Writing',
        status: QuestActivityStatus.incomplete,
        timestamp: today.add(const Duration(hours: 16)),
      );

      // Query entries for date
      final dateEntries = await repository.getEntriesForDate(today);
      expect(dateEntries.length, equals(3));

      final completed = dateEntries.where((e) => e.isCompleted).toList();
      expect(completed.length, equals(1));
      expect(completed.first.questTitle, equals('Visit City Park'));
      expect(completed.first.xpReward, equals(100));

      final failed = dateEntries.where((e) => e.isFailed).toList();
      expect(failed.length, equals(1));
      expect(failed.first.questTitle, equals('High Altitude Peak'));
      expect(failed.first.failureReason, contains('GPS distance exceeded'));

      final incomplete = dateEntries.where((e) => e.isIncomplete).toList();
      expect(incomplete.length, equals(1));
      expect(incomplete.first.questTitle, equals('Write City Lore'));
    });

    test('QuestCalendarNotifier correctly aggregates daily stats and monthStatusMap', () async {
      final mockStorage = MockTestLocalStorageService();
      final localDataSource = QuestCalendarLocalDataSource(mockStorage);
      final repository = QuestCalendarRepositoryImpl(localDataSource: localDataSource);
      final notifier = QuestCalendarNotifier(repository);

      final date = DateTime(2026, 9, 2);
      await notifier.selectDate(date);

      await notifier.recordActivity(
        questId: 'q_cal_comp',
        questTitle: 'Completed Quest',
        category: 'Landmark',
        status: QuestActivityStatus.completed,
        timestamp: date,
        xpReward: 200,
        coinReward: 100,
      );

      await notifier.recordActivity(
        questId: 'q_cal_fail',
        questTitle: 'Failed Quest',
        category: 'Fitness',
        status: QuestActivityStatus.failed,
        timestamp: date,
        failureReason: 'Anti-cheat signature detected',
      );

      final state = notifier.state;
      expect(state.dailyCompletedCount, equals(1));
      expect(state.dailyFailedCount, equals(1));
      expect(state.dailyXpEarned, equals(200));
      expect(state.dailyCoinsEarned, equals(100));

      final statusDots = state.monthStatusMap[2] ?? [];
      expect(statusDots, contains(QuestActivityStatus.completed));
      expect(statusDots, contains(QuestActivityStatus.failed));
    });
  });

  group('Location Permission & GPS Service Flow Tests', () {
    test('Scenario 1: Fresh install -> ALLOW LOCATION -> Request permission -> Granted -> GPS ON -> locationReady', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.denied,
        requestResult: LocationPermission.whileInUse,
        isGpsEnabled: true,
        mockCoords: LocationCoordinates(
          latitude: 13.9182,
          longitude: 75.0682,
          accuracy: 5.0,
          timestamp: DateTime.now(),
        ),
      );
      final mockStorage = MockTestLocalStorageService();

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);

      // Tap ALLOW LOCATION
      final success = await notifier.requestAndAcquireLocation();
      expect(success, isTrue);

      final state = container.read(locationPermissionNotifierProvider);
      expect(state.status, equals(LocationPermissionUIState.locationReady));
      expect(state.coordinates, isNotNull);
      expect(state.coordinates!.latitude, equals(13.9182));
      expect(state.coordinates!.longitude, equals(75.0682));
    });

    test('Scenario 2: Permission granted but GPS is OFF -> ALLOW LOCATION -> gpsDisabled state', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.whileInUse,
        isGpsEnabled: false,
      );
      final mockStorage = MockTestLocalStorageService();

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);

      // Tap ALLOW LOCATION
      final success = await notifier.requestAndAcquireLocation();
      expect(success, isFalse);

      final state = container.read(locationPermissionNotifierProvider);
      expect(state.status, equals(LocationPermissionUIState.gpsDisabled));
      expect(state.message, contains('Location services are disabled'));
    });

    test('Scenario 3: Permission denied by user -> permissionDenied state', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.denied,
        requestResult: LocationPermission.denied,
        isGpsEnabled: true,
      );
      final mockStorage = MockTestLocalStorageService();

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);

      final success = await notifier.requestAndAcquireLocation();
      expect(success, isFalse);

      final state = container.read(locationPermissionNotifierProvider);
      expect(state.status, equals(LocationPermissionUIState.permissionDenied));
      expect(state.message, contains('Location permission is required'));
    });

    test('Scenario 4: Permission permanently denied -> permissionDeniedForever state', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.deniedForever,
        isGpsEnabled: true,
      );
      final mockStorage = MockTestLocalStorageService();

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);

      final success = await notifier.requestAndAcquireLocation();
      expect(success, isFalse);

      final state = container.read(locationPermissionNotifierProvider);
      expect(state.status, equals(LocationPermissionUIState.permissionDeniedForever));
      expect(state.message, contains('permanently denied'));
    });

    test('Scenario 5: User turns GPS ON in Settings and returns to QuestUP -> checkAndAutoResume acquires location', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.whileInUse,
        isGpsEnabled: false,
        mockCoords: LocationCoordinates(
          latitude: 12.9716,
          longitude: 77.5946,
          accuracy: 4.0,
          timestamp: DateTime.now(),
        ),
      );
      final mockStorage = MockTestLocalStorageService();

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);

      // Initially GPS is OFF
      await notifier.requestAndAcquireLocation();
      expect(container.read(locationPermissionNotifierProvider).status, equals(LocationPermissionUIState.gpsDisabled));

      // User turns GPS ON in Android Settings
      mockLoc.isGpsEnabled = true;

      // User returns to app (AppLifecycleState.resumed triggers checkAndAutoResume)
      final autoResumed = await notifier.checkAndAutoResume();
      expect(autoResumed, isTrue);

      final updatedState = container.read(locationPermissionNotifierProvider);
      expect(updatedState.status, equals(LocationPermissionUIState.locationReady));
      expect(updatedState.coordinates?.latitude, equals(12.9716));
    });
  });

  group('Smart Proof Verification System 12 Scenarios', () {
    late MockTestLocalStorageService storage;
    late VerificationLocalDataSource verificationLocalDataSource;
    late DuplicateProofService duplicateProofService;
    late QuestVerificationService verificationService;
    late UserRepositoryImpl userRepository;
    late QuestRepositoryImpl questRepository;
    late AchievementRepositoryImpl achievementRepository;
    late QuestCalendarRepositoryImpl calendarRepository;
    late VerificationRepositoryImpl verificationRepo;

    setUp(() {
      storage = MockTestLocalStorageService();
      verificationLocalDataSource = VerificationLocalDataSource(storage);
      duplicateProofService = DuplicateProofService(verificationLocalDataSource);
      verificationService = QuestVerificationService(duplicateProofService: duplicateProofService);

      final userProfile = UserProfileModel(
        id: 'player_123',
        name: 'Smart Hunter',
        email: 'hunter@questup.com',
        avatarKey: 'avatar_ranger',
        level: 1,
        currentXp: 100,
        xpToNextLevel: 500,
        coins: 50,
        completedQuestIds: const [],
        earnedBadgeIds: const [],
        joinedAt: DateTime.now(),
      );
      final userDs = MockUserLocalDataSource(userProfile);
      userRepository = UserRepositoryImpl(userDs);

      final questList = [
        const QuestModel(
          id: 'q_geo_photo',
          title: 'Kodachadri Viewpoint Photo',
          description: 'Take a photo at the peak',
          storyline: 'Nature',
          category: QuestCategory.nature,
          difficulty: QuestDifficulty.easy,
          latitude: 13.8560,
          longitude: 74.8720,
          locationName: 'Kodachadri Peak',
          radiusMeters: 75,
          xpReward: 150,
          coinReward: 50,
          requiredLevel: 1,
          requiresFreshPhoto: true,
          requiredObject: 'peak',
          requirements: [],
          iconKey: 'nature',
        ),
        const QuestModel(
          id: 'q_10min_book',
          title: 'Read Book for 10 Minutes',
          description: 'Record 10-minute continuous reading session',
          storyline: 'Study',
          category: QuestCategory.reading,
          difficulty: QuestDifficulty.medium,
          latitude: 0,
          longitude: 0,
          locationName: 'Library',
          radiusMeters: 0,
          xpReward: 200,
          coinReward: 80,
          requiredLevel: 1,
          requiresVideo: true,
          requiredDurationSeconds: 600, // 10 minutes
          requirements: [],
          iconKey: 'reading',
        ),
        const QuestModel(
          id: 'q_cow_photo',
          title: 'Find a cow and take a photo',
          description: 'Find a real cow and take a new photo using the QuestUP camera',
          storyline: 'Rural Adventure',
          category: QuestCategory.nature,
          difficulty: QuestDifficulty.easy,
          latitude: 0,
          longitude: 0,
          locationName: 'Countryside',
          radiusMeters: 0,
          xpReward: 150,
          coinReward: 60,
          requiredLevel: 1,
          requiresPhoto: true,
          requiresFreshPhoto: true,
          requiredObject: 'cow',
          requirements: [],
          iconKey: 'nature',
        ),
      ];
      final questDs = MockQuestLocalDataSource(questList);
      final mysqlDs = MockQuestMySqlDataSource();
      questRepository = QuestRepositoryImpl(
        localDataSource: questDs,
        mySqlDataSource: mysqlDs,
      );

      final achieveDs = AchievementLocalDataSource(storage);
      achievementRepository = AchievementRepositoryImpl(achieveDs);

      final calDs = QuestCalendarLocalDataSource(storage);
      calendarRepository = QuestCalendarRepositoryImpl(localDataSource: calDs);

      verificationRepo = VerificationRepositoryImpl(
        localDataSource: verificationLocalDataSource,
        questRepository: questRepository,
        userRepository: userRepository,
        achievementRepository: achievementRepository,
        calendarRepository: calendarRepository,
        duplicateProofService: duplicateProofService,
        verificationService: verificationService,
      );
    });

    // TEST 1: Player is at correct location + valid photo -> VERIFIED
    test('TEST 1: Player is at correct location + valid photo -> VERIFIED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
        startingLat: 13.8560,
        startingLon: 74.8720,
      );

      final quest = (await questRepository.getQuestById('q_geo_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        userLat: 13.8560, // Exactly at location (0 meters away)
        userLon: 74.8720,
        photoProofPath: 'camera_capture_peak_123.jpg',
        mediaHash: 'unique_hash_test_1',
      );

      expect(result.isSuccessful, isTrue);
      expect(result.xpEarned, equals(150));
      expect(result.coinsEarned, equals(50));

      final updatedProfile = await userRepository.getUserProfile();
      expect(updatedProfile.currentXp, equals(250)); // 100 + 150
      expect(updatedProfile.coins, equals(100)); // 50 + 50
      expect(updatedProfile.completedQuestIds, contains('q_geo_photo'));
    });

    // TEST 2: Player is far from location -> REJECTED
    test('TEST 2: Player is far from location -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );

      final quest = (await questRepository.getQuestById('q_geo_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        userLat: 12.9716, // Bangalore (~300 km away)
        userLon: 77.5946,
        photoProofPath: 'camera_capture_peak_456.jpg',
        mediaHash: 'unique_hash_test_2',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('GPS Proximity Check Failed'));

      final updatedProfile = await userRepository.getUserProfile();
      expect(updatedProfile.currentXp, equals(100)); // No rewards awarded
      expect(updatedProfile.coins, equals(50));
    });

    // TEST 3: Player denies GPS permission -> Clear error
    test('TEST 3: Player denies GPS permission -> Clear error', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.denied,
        requestResult: LocationPermission.denied,
      );
      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);
      await notifier.requestAndAcquireLocation();

      final state = container.read(locationPermissionNotifierProvider);
      expect(state.status, equals(LocationPermissionUIState.permissionDenied));
    });

    // TEST 4: GPS disabled -> Clear message + settings option
    test('TEST 4: GPS disabled -> Clear message + settings option', () async {
      final mockLoc = MockTestLocationService(
        initialPermission: LocationPermission.whileInUse,
        isGpsEnabled: false,
      );
      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLoc),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final notifier = container.read(locationPermissionNotifierProvider.notifier);
      await notifier.requestAndAcquireLocation();

      final state = container.read(locationPermissionNotifierProvider);
      expect(state.status, equals(LocationPermissionUIState.gpsDisabled));
    });

    // TEST 5: Old/gallery proof on fresh-photo quest -> Reject or mark
    test('TEST 5: Old/gallery proof on fresh-photo quest -> Reject', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );

      final quest = (await questRepository.getQuestById('q_geo_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        userLat: 13.8560,
        userLon: 74.8720,
        payload: VerificationProofPayload(
          userLat: 13.8560,
          userLon: 74.8720,
          photoProofPath: 'gallery_download_old_image.jpg',
          isFreshCameraCapture: false, // Gallery upload
          sessionId: session.sessionId,
          questSession: session,
          mediaHash: 'unique_gallery_hash',
        ),
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Fresh Photo Required'));
    });

    // TEST 6: Same proof submitted twice -> Duplicate detected
    test('TEST 6: Same proof submitted twice -> Duplicate detected', () async {
      const duplicateHash = 'duplicate_proof_sha256_abcdef';

      // 1. First submission succeeds
      final session1 = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );
      final quest = (await questRepository.getQuestById('q_geo_photo'))!;

      final result1 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session1.sessionId,
        userLat: 13.8560,
        userLon: 74.8720,
        photoProofPath: 'camera_capture_peak_first.jpg',
        mediaHash: duplicateHash,
      );
      expect(result1.isSuccessful, isTrue);

      // 2. Second submission with the same proof hash is rejected
      final session2 = await verificationRepo.startQuestSession(
        questId: 'q_10min_book',
        userId: 'player_123',
      );
      final quest2 = (await questRepository.getQuestById('q_10min_book'))!;

      final result2 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest2,
        sessionId: session2.sessionId,
        videoProofPath: 'video_reading.mp4',
        durationSeconds: 600,
        mediaHash: duplicateHash, // Reused hash
      );

      expect(result2.isSuccessful, isFalse);
      expect(result2.message, contains('This proof has already been used'));
    });

    // TEST 7: Video is 9 minutes for a 10-minute quest -> REJECTED
    test('TEST 7: Video is 9 minutes for a 10-minute quest -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_10min_book',
        userId: 'player_123',
      );

      final quest = (await questRepository.getQuestById('q_10min_book'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        videoProofPath: 'reading_proof.mp4',
        durationSeconds: 552, // 9 minutes 12 seconds
        mediaHash: 'unique_video_hash_9min',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Your video is only 9 minutes 12 seconds. You need at least 10 minutes.'));
    });

    // TEST 8: Video is 10+ minutes -> Duration check passes
    test('TEST 8: Video is 10+ minutes -> Duration check passes', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_10min_book',
        userId: 'player_123',
      );

      final quest = (await questRepository.getQuestById('q_10min_book'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        videoProofPath: 'reading_proof.mp4',
        durationSeconds: 618, // 10 minutes 18 seconds
        mediaHash: 'unique_video_hash_10min',
      );

      expect(result.isSuccessful, isTrue);
      expect(result.xpEarned, equals(200));
      expect(result.coinsEarned, equals(80));
    });

    // TEST 9: Network/storage temporarily unavailable -> No reward
    test('TEST 9: Repeated verification failures never grant rewards', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );

      final quest = (await questRepository.getQuestById('q_geo_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        userLat: 0.0,
        userLon: 0.0, // Invalid coordinates
      );

      expect(result.isSuccessful, isFalse);
      final profile = await userRepository.getUserProfile();
      expect(profile.completedQuestIds, isNot(contains('q_geo_photo')));
    });

    // TEST 10: User presses Complete multiple times -> Only one completion and one reward
    test('TEST 10: User presses Complete multiple times -> Only one completion and one reward', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );

      final quest = (await questRepository.getQuestById('q_geo_photo'))!;

      // First completion
      final result1 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        userLat: 13.8560,
        userLon: 74.8720,
        photoProofPath: 'camera_capture_peak_once.jpg',
        mediaHash: 'unique_hash_once',
      );
      expect(result1.isSuccessful, isTrue);

      // Second completion attempt
      final result2 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        userLat: 13.8560,
        userLon: 74.8720,
        photoProofPath: 'camera_capture_peak_once.jpg',
        mediaHash: 'unique_hash_once_2',
      );
      expect(result2.isSuccessful, isFalse);
      expect(result2.message, contains('already completed'));

      final profile = await userRepository.getUserProfile();
      expect(profile.currentXp, equals(250)); // Only awarded once (+150 XP)
    });

    // TEST 11: User tries to submit proof for an expired/old session -> REJECTED
    test('TEST 11: User tries to submit proof for an expired/old session -> REJECTED', () async {
      final expiredSession = QuestSession(
        sessionId: 'expired_sess_1',
        userId: 'player_123',
        questId: 'q_geo_photo',
        startedAt: DateTime.now().subtract(const Duration(hours: 30)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 6)),
        status: QuestSessionStatus.inProgress,
      );
      await verificationLocalDataSource.saveQuestSession(expiredSession);

      final quest = (await questRepository.getQuestById('q_geo_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: expiredSession.sessionId,
        userLat: 13.8560,
        userLon: 74.8720,
        photoProofPath: 'camera_capture_peak_exp.jpg',
        mediaHash: 'unique_hash_expired_test',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Quest Session Expired'));
    });

    // TEST 12: App is closed and reopened during a quest -> Existing session is handled correctly
    test('TEST 12: App is closed and reopened during a quest -> Existing session is handled correctly', () async {
      // 1. Session started before app close
      final originalSession = await verificationRepo.startQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );

      // 2. App restarts / new instance reads from local storage
      final activeSession = await verificationRepo.getActiveQuestSession(
        questId: 'q_geo_photo',
        userId: 'player_123',
      );

      expect(activeSession, isNotNull);
      expect(activeSession!.sessionId, equals(originalSession.sessionId));
      expect(activeSession.isActive, isTrue);

      // 3. User continues and completes with restored active session
      final quest = (await questRepository.getQuestById('q_geo_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: activeSession.sessionId,
        userLat: 13.8560,
        userLon: 74.8720,
        photoProofPath: 'camera_capture_peak_restored.jpg',
        mediaHash: 'unique_hash_restored_test',
      );

      expect(result.isSuccessful, isTrue);
    });
  });

  group('Multi-Signal Anti-Cheat Screen & Photo-of-Photo Verification Tests', () {
    late VerificationRepositoryImpl verificationRepo;
    late QuestRepositoryImpl questRepository;
    late UserRepositoryImpl userRepository;
    late AchievementRepositoryImpl achievementRepository;
    late QuestCalendarRepositoryImpl calendarRepository;
    late VerificationLocalDataSource verificationLocalDataSource;
    late DuplicateProofService duplicateProofService;
    late QuestVerificationService verificationService;
    late MockTestLocalStorageService storage;

    setUp(() async {
      storage = MockTestLocalStorageService();
      verificationLocalDataSource = VerificationLocalDataSource(storage);
      duplicateProofService = DuplicateProofService(verificationLocalDataSource);
      verificationService = QuestVerificationService(
        duplicateProofService: duplicateProofService,
        authenticityService: const SceneAuthenticityService(),
      );

      final userProfile = UserProfileModel(
        id: 'anti_cheat_player',
        name: 'Anti-Cheat Tester',
        email: 'tester@questup.com',
        avatarKey: 'avatar_ranger',
        level: 1,
        currentXp: 100,
        xpToNextLevel: 500,
        coins: 50,
        completedQuestIds: const [],
        earnedBadgeIds: const [],
        joinedAt: DateTime.now(),
      );
      final userDs = UserLocalDataSource(storage);
      await userDs.saveUserProfile(userProfile);
      userRepository = UserRepositoryImpl(userDs);

      final questList = [
        const QuestModel(
          id: 'q_cow_photo',
          title: 'Find a cow and take a photo',
          description: 'Find a real cow and take a new photo using the QuestUP camera',
          storyline: 'Rural Adventure',
          category: QuestCategory.nature,
          difficulty: QuestDifficulty.easy,
          latitude: 0,
          longitude: 0,
          locationName: 'Pasture Field',
          radiusMeters: 0,
          xpReward: 150,
          coinReward: 60,
          requiredLevel: 1,
          requiresPhoto: true,
          requiresFreshPhoto: true,
          requiredObject: 'cow',
          requirements: [],
          iconKey: 'nature',
        ),
      ];
      final questDs = MockQuestLocalDataSource(questList);
      questRepository = QuestRepositoryImpl(
        localDataSource: questDs,
        mySqlDataSource: MockQuestMySqlDataSource(),
      );

      final achieveDs = AchievementLocalDataSource(storage);
      achievementRepository = AchievementRepositoryImpl(achieveDs);

      final calDs = QuestCalendarLocalDataSource(storage);
      calendarRepository = QuestCalendarRepositoryImpl(localDataSource: calDs);

      verificationRepo = VerificationRepositoryImpl(
        localDataSource: verificationLocalDataSource,
        questRepository: questRepository,
        userRepository: userRepository,
        achievementRepository: achievementRepository,
        calendarRepository: calendarRepository,
        duplicateProofService: duplicateProofService,
        verificationService: verificationService,
      );
    });

    // TEST 1: Real cow + QuestUP camera + natural surroundings + valid active session -> VERIFIED
    test('TEST 1: Real cow + QuestUP camera + natural surroundings + valid active session -> VERIFIED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_real_cow_field_1.jpg',
        mediaHash: 'unique_cow_proof_hash_1',
      );

      expect(result.isSuccessful, isTrue);
      expect(result.xpEarned, equals(150));
      expect(result.coinsEarned, equals(60));

      final updatedProfile = await userRepository.getUserProfile();
      expect(updatedProfile.currentXp, equals(250)); // 100 + 150
      expect(updatedProfile.coins, equals(110)); // 50 + 60
      expect(updatedProfile.completedQuestIds, contains('q_cow_photo'));
    });

    // TEST 2: Cow picture displayed on another phone + QuestUP camera -> REJECTED
    test('TEST 2: Cow picture displayed on another phone + QuestUP camera -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_cow_displayed_on_phone_screen.jpg',
        mediaHash: 'unique_cheat_phone_screen_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Please photograph a real cow, not an image displayed on another phone, computer, or digital screen.'));

      final profile = await userRepository.getUserProfile();
      expect(profile.completedQuestIds, isNot(contains('q_cow_photo')));
      expect(profile.currentXp, equals(100)); // Zero rewards granted
    });

    // TEST 3: Cow picture on computer monitor -> REJECTED
    test('TEST 3: Cow picture on computer monitor -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_cow_on_computer_monitor_screen.jpg',
        mediaHash: 'unique_cheat_monitor_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Please photograph a real cow, not an image displayed on another phone, computer, or digital screen.'));
    });

    // TEST 4: Printed cow photograph -> REJECTED or REVIEW_REQUIRED
    test('TEST 4: Printed cow photograph -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_printed_cow_poster.jpg',
        mediaHash: 'unique_cheat_poster_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('This appears to be a photo of a printed image or poster. Please photograph a real cow'));
    });

    // TEST 5: Screenshot of cow -> REJECTED
    test('TEST 5: Screenshot of cow -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'screenshot_cow_search.jpg',
        mediaHash: 'unique_cheat_screenshot_hash',
      );

      expect(result.isSuccessful, isFalse);
    });

    // TEST 6: Gallery photo of cow on camera_only quest -> REJECTED / gallery unavailable
    test('TEST 6: Gallery photo of cow on camera_only quest -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'gallery_cow_downloaded.jpg',
        mediaHash: 'unique_cheat_gallery_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Fresh Photo Required: This quest requires taking a live photo right now using the in-app QuestUP camera. Gallery uploads are not permitted.'));
    });

    // TEST 7: Real cow photo captured during active session -> VERIFIED
    test('TEST 7: Real cow photo captured during active session -> VERIFIED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_cow_farm_pasture_live.jpg',
        mediaHash: 'unique_real_cow_live_hash',
      );

      expect(result.isSuccessful, isTrue);
      expect(result.xpEarned, equals(150));
    });

    // TEST 8: Old proof from previous session -> REJECTED
    test('TEST 8: Old proof from previous session -> REJECTED', () async {
      final session = QuestSession(
        sessionId: 'old_cow_session_expired',
        userId: 'anti_cheat_player',
        questId: 'q_cow_photo',
        startedAt: DateTime.now().subtract(const Duration(hours: 48)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 24)),
        status: QuestSessionStatus.inProgress,
      );
      await verificationLocalDataSource.saveQuestSession(session);

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_real_cow_live.jpg',
        mediaHash: 'unique_cow_old_session_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Quest Session Expired'));
    });

    // TEST 9: Same image reused -> Duplicate detected
    test('TEST 9: Same image reused -> Duplicate detected', () async {
      const duplicateCowHash = 'sha256_cow_proof_12345';

      // 1. Submit first cow proof
      final session1 = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );
      final quest = (await questRepository.getQuestById('q_cow_photo'))!;

      final result1 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session1.sessionId,
        photoProofPath: 'camera_capture_real_cow_proof1.jpg',
        mediaHash: duplicateCowHash,
      );
      expect(result1.isSuccessful, isTrue);

      // 2. Submit same hash for a second quest
      final quest2 = const QuestModel(
        id: 'q_cow_photo_field_2',
        title: 'Find a second cow',
        description: 'Take another cow photo',
        storyline: 'Nature',
        category: QuestCategory.nature,
        difficulty: QuestDifficulty.easy,
        latitude: 0,
        longitude: 0,
        locationName: 'Second Field',
        radiusMeters: 0,
        xpReward: 150,
        coinReward: 60,
        requiredLevel: 1,
        requiresPhoto: true,
        requiresFreshPhoto: true,
        requiredObject: 'cow',
        requirements: [],
        iconKey: 'nature',
      );

      final session2 = await verificationRepo.startQuestSession(
        questId: quest2.id,
        userId: 'anti_cheat_player',
      );

      final result2 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest2,
        sessionId: session2.sessionId,
        photoProofPath: 'camera_capture_real_cow_proof2.jpg',
        mediaHash: duplicateCowHash, // Duplicate fingerprint!
      );

      expect(result2.isSuccessful, isFalse);
      expect(result2.message, contains('This proof has already been used'));
    });

    // TEST 10: Image contains no cow -> REJECTED
    test('TEST 10: Image contains no cow -> REJECTED', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_no_cow_empty_parking_lot.jpg',
        mediaHash: 'unique_no_cow_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('No Cow detected. Please photograph a real cow.'));
    });

    // TEST 11: Very tightly cropped suspicious image -> REVIEW_REQUIRED / RETRY
    test('TEST 11: Very tightly cropped suspicious image -> REVIEW_REQUIRED / RETRY', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;
      final result = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_cow_tight_crop_suspicious.jpg',
        mediaHash: 'unique_tight_crop_hash',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.message, contains('Please take another photo of the cow in a wider real-world scene with its surroundings visible.'));
    });

    // TEST 12: User presses Complete repeatedly -> Only one successful completion and one reward
    test('TEST 12: User presses Complete repeatedly -> Only one successful completion and one reward', () async {
      final session = await verificationRepo.startQuestSession(
        questId: 'q_cow_photo',
        userId: 'anti_cheat_player',
      );

      final quest = (await questRepository.getQuestById('q_cow_photo'))!;

      // 1st press
      final result1 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_real_cow_once.jpg',
        mediaHash: 'unique_once_cow_hash',
      );
      expect(result1.isSuccessful, isTrue);

      // 2nd press
      final result2 = await verificationRepo.verifyAndCompleteQuest(
        quest: quest,
        sessionId: session.sessionId,
        photoProofPath: 'camera_capture_real_cow_twice.jpg',
        mediaHash: 'unique_twice_cow_hash',
      );
      expect(result2.isSuccessful, isFalse);
      expect(result2.message, contains('Quest already completed'));

      final profile = await userRepository.getUserProfile();
      expect(profile.currentXp, equals(250)); // Only 1x 150 reward granted
      expect(profile.coins, equals(110)); // Only 1x 60 reward granted
    });
  });

  group('AppConstants & AppExternalService Tests', () {
    test('AppConstants contains correct Android applicationId and Play Store URLs', () {
      expect(AppConstants.androidApplicationId, equals('com.questup.quest_up'));
      expect(AppConstants.playStoreMarketUri, equals('market://details?id=com.questup.quest_up'));
      expect(AppConstants.playStoreWebUrl, equals('https://play.google.com/store/apps/details?id=com.questup.quest_up'));
      expect(AppConstants.privacyPolicyUrl, contains('privacy-policy'));
      expect(AppConstants.shareMessage, contains("I'm using QuestUP!"));
      expect(AppConstants.shareMessage, contains('https://play.google.com/store/apps/details?id=com.questup.quest_up'));
    });
  });
}

class MockTestLocalStorageService implements ILocalStorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> saveString(String key, String value) async => _data[key] = value;

  @override
  Future<String?> getString(String key) async => _data[key]?.toString();

  @override
  Future<void> saveJson(String key, dynamic value) async => _data[key] = value;

  @override
  Future<dynamic> getJson(String key) async => _data[key];

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}

class MockTestLocationService implements ILocationService {
  LocationPermission initialPermission;
  LocationPermission requestResult;
  bool isGpsEnabled;
  LocationCoordinates? mockCoords;

  MockTestLocationService({
    this.initialPermission = LocationPermission.denied,
    this.requestResult = LocationPermission.whileInUse,
    this.isGpsEnabled = true,
    this.mockCoords,
  });

  @override
  Future<LocationPermission> checkPermission() async => initialPermission;

  @override
  Future<LocationPermission> requestPermission() async {
    initialPermission = requestResult;
    return requestResult;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => isGpsEnabled;

  @override
  Future<bool> hasLocationPermission() async =>
      initialPermission == LocationPermission.always || initialPermission == LocationPermission.whileInUse;

  @override
  Future<bool> isLocationEnabledAndPermitted() async => isGpsEnabled && await hasLocationPermission();

  @override
  Future<LocationCoordinates> getCurrentLocation() async =>
      mockCoords ??
      LocationCoordinates(
        latitude: 13.9182,
        longitude: 75.0682,
        accuracy: 5.0,
        timestamp: DateTime.now(),
      );

  @override
  Future<LocationCoordinates> getRealDeviceLocation() async => getCurrentLocation();

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Stream<LocationCoordinates> get locationStream => const Stream.empty();

  @override
  void setSimulatedLocation(double latitude, double longitude) {}

  @override
  void clearSimulatedLocation() {}

  @override
  bool get isSimulated => false;
}

