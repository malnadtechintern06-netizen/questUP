import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/auth/data/models/auth_user_model.dart';
import 'package:quest_up/features/profile/data/models/user_profile_model.dart';
import 'package:quest_up/features/profile/data/repositories/user_repository_impl.dart';
import 'package:quest_up/features/profile/data/datasources/user_local_datasource.dart';
import 'package:quest_up/core/services/google_place_photo_service.dart';
import 'package:quest_up/features/quests/data/datasources/quest_firestore_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/models/quest_model.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/utils/quest_image_resolver.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/services/quest_verification_service.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';

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

class MockQuestFirestoreDataSource implements IQuestFirestoreDataSource {
  @override
  Future<List<QuestModel>> fetchQuestsFromFirestore() async => [];

  @override
  Future<void> saveQuestToFirestore(QuestModel quest) async {}

  @override
  Future<void> markCompletedInFirestore(String questId, String userId) async {}
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
      final mockRemote = MockQuestFirestoreDataSource();
      final repo = QuestRepositoryImpl(
        localDataSource: mockLocal,
        firestoreDataSource: mockRemote,
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
}
