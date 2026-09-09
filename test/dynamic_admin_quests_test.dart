import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/features/quests/data/models/quest_model.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';

class MockLocalDataSource implements IQuestLocalDataSource {
  List<QuestModel> saved = [];
  @override
  Future<List<QuestModel>> getQuests() async => [];
  @override
  Future<List<QuestModel>> getQuestsForLocation(double userLat, double userLon, {double maxRadiusMeters = 50000.0}) async => [];
  @override
  Future<void> saveQuests(List<QuestModel> quests) async {
    saved = quests;
  }
  @override
  Future<QuestModel?> getQuestById(String id) async => null;
  @override
  Future<void> markCompleted(String id) async {}
  @override
  Future<List<Map<String, dynamic>>> getLocalSharedQuests() async => [];
  @override
  Future<void> saveLocalSharedQuests(List<Map<String, dynamic>> sharedQuests) async {}
}

class MockDynamicAdminDataSource implements IQuestMySqlDataSource {
  final List<QuestModel> quests;
  MockDynamicAdminDataSource(this.quests);

  @override
  Future<List<QuestModel>> fetchQuestsFromMySql({
    String? userId,
    double? userLat,
    double? userLon,
  }) async => quests;

  @override
  Future<List<QuestModel>> generateLocationQuests({
    required double latitude,
    required double longitude,
    String? userId,
    int? radiusMeters,
  }) async => [];

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
  group('Dynamic Admin Panel Quest Creation & In-App Verification Tests', () {
    test('QuestModel dynamically deserializes all custom admin panel verification rules and parameters', () {
      final adminCreatedJson = <String, dynamic>{
        'id': 'admin_custom_car_quest_001',
        'title': 'Spot a Rare Sports Car',
        'description': 'Search the city streets and photograph a red sports car.',
        'storyline': 'The grand automotive rally has arrived in town!',
        'category': 'photo',
        'verificationType': 'photoProof',
        'latitude': 12.9750,
        'longitude': 77.5980,
        'radiusMeters': 200.0,
        'xpReward': 500,
        'coinReward': 250,
        'locationName': 'City Center Boulevard',
        'placeType': 'street',
        'photoUrl': 'assets/images/sports_car.jpg',
        'imageUrl': 'assets/images/sports_car.jpg',
        'difficulty': 'hard',
        'isActive': true,
        'iconKey': 'camera_alt',
        'requiredObject': 'car',
        'requiredDrawingSubject': null,
        'requiredWords': 0,
        'requiredDurationSeconds': 0,
        'requiredDistanceMeters': 0.0,
        'requiresGPS': true,
        'requiresPhoto': true,
        'requiresFreshPhoto': true,
        'requiresVideo': false,
        'requiresDrawing': false,
        'requiresText': false,
        'requiresGameSession': false,
        'createdAt': '2026-09-07 12:20:00',
      };

      final quest = QuestModel.fromJson(adminCreatedJson);

      expect(quest.id, equals('admin_custom_car_quest_001'));
      expect(quest.title, equals('Spot a Rare Sports Car'));
      expect(quest.storyline, equals('The grand automotive rally has arrived in town!'));
      expect(quest.category, equals(QuestCategory.photo));
      expect(quest.verificationType, equals(QuestVerificationType.photoProof));
      expect(quest.xpReward, equals(500));
      expect(quest.coinReward, equals(250));
      expect(quest.requiredObject, equals('car'));
      expect(quest.requiresGPS, isTrue);
      expect(quest.requiresPhoto, isTrue);
      expect(quest.requiresFreshPhoto, isTrue);
      expect(quest.requirements.length, greaterThanOrEqualTo(1));
      expect(quest.requirements.any((r) => r.description.contains('car')), isTrue);
    });

    test('QuestModel dynamically deserializes custom drawing & writing quests from admin panel', () {
      final drawingQuestJson = <String, dynamic>{
        'id': 'admin_draw_sunset_002',
        'title': 'Sketch a Mountain Sunset',
        'description': 'Draw a vibrant sunset behind mountains on your canvas.',
        'storyline': 'Harness your creative artistic spirit.',
        'category': 'drawing',
        'verificationType': 'drawingCanvas',
        'latitude': 0.0,
        'longitude': 0.0,
        'radiusMeters': 75.0,
        'xpReward': 350,
        'coinReward': 175,
        'locationName': 'Creative Studio',
        'difficulty': 'medium',
        'isActive': true,
        'iconKey': 'brush',
        'requiredDrawingSubject': 'sunset',
        'requiresDrawing': true,
      };

      final drawQuest = QuestModel.fromJson(drawingQuestJson);
      expect(drawQuest.requiredDrawingSubject, equals('sunset'));
      expect(drawQuest.requiresDrawing, isTrue);
      expect(drawQuest.requirements.any((r) => r.title.contains('Draw sunset')), isTrue);

      final writingQuestJson = <String, dynamic>{
        'id': 'admin_write_memoir_003',
        'title': 'Write 250 Words on Space Exploration',
        'description': 'Reflect on human exploration in your logbook.',
        'category': 'writing',
        'verificationType': 'writingText',
        'latitude': 0.0,
        'longitude': 0.0,
        'xpReward': 400,
        'coinReward': 200,
        'requiredWords': 250,
        'requiresText': true,
        'iconKey': 'edit_note',
      };

      final writeQuest = QuestModel.fromJson(writingQuestJson);
      expect(writeQuest.requiredWords, equals(250));
      expect(writeQuest.requiresText, isTrue);
      expect(writeQuest.requirements.any((r) => r.description.contains('250 words')), isTrue);
    });

    test('QuestRepositoryImpl delivers newly added admin quests seamlessly to getQuests and getNearbyQuests', () async {
      final dynamicAdminQuest = QuestModel(
        id: 'admin_live_quest_999',
        title: 'New Admin Master Trial',
        description: 'Dynamically generated quest from admin panel without hardcoding.',
        storyline: 'The ancient trial awaits.',
        category: QuestCategory.photo,
        difficulty: QuestDifficulty.legendary,
        verificationType: QuestVerificationType.photoProof,
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Bangalore City Square',
        radiusMeters: 150.0,
        xpReward: 1000,
        coinReward: 500,
        requiredLevel: 1,
        requirements: const [],
        iconKey: 'camera_alt',
        requiredObject: 'statue',
        requiresPhoto: true,
        requiresFreshPhoto: true,
      );

      final mockLocal = MockLocalDataSource();
      final mockRemote = MockDynamicAdminDataSource([dynamicAdminQuest]);
      final repo = QuestRepositoryImpl(
        localDataSource: mockLocal,
        mySqlDataSource: mockRemote,
      );

      final quests = await repo.getQuests();
      expect(quests.length, equals(1));
      expect(quests.first.id, equals('admin_live_quest_999'));
      expect(quests.first.title, equals('New Admin Master Trial'));
      expect(quests.first.requiredObject, equals('statue'));
      expect(quests.first.xpReward, equals(1000));

      final nearby = await repo.getNearbyQuests(
        userLat: 12.9716,
        userLon: 77.5946,
        maxDistanceMeters: 5000,
      );
      expect(nearby.length, equals(1));
      expect(nearby.first.id, equals('admin_live_quest_999'));
      expect(nearby.first.distanceMeters, isNotNull);
      expect(nearby.first.distanceMeters!, lessThan(50));
    });
  });
}
