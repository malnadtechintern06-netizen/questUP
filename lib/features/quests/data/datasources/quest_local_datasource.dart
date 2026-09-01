import '../../../../app/config/app_constants.dart';
import '../../../../core/services/activity_quest_catalog_service.dart';
import '../../../../core/services/places_discovery_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/quest_model.dart';

abstract class IQuestLocalDataSource {
  Future<List<QuestModel>> getQuests();
  Future<List<QuestModel>> getQuestsForLocation(
    double userLat,
    double userLon, {
    double maxRadiusMeters = 5000.0,
  });
  Future<void> saveQuests(List<QuestModel> quests);
  Future<QuestModel?> getQuestById(String id);
  Future<void> markCompleted(String id);
}

class QuestLocalDataSource implements IQuestLocalDataSource {
  final ILocalStorageService _storage;
  final IPlacesDiscoveryService _placesDiscoveryService;
  final IActivityQuestCatalogService _activityCatalogService;

  QuestLocalDataSource(
    this._storage, [
    IPlacesDiscoveryService? placesDiscoveryService,
    IActivityQuestCatalogService? activityCatalogService,
  ])  : _placesDiscoveryService =
            placesDiscoveryService ?? PlacesDiscoveryService(),
        _activityCatalogService =
            activityCatalogService ?? ActivityQuestCatalogService();

  @override
  Future<List<QuestModel>> getQuests() async {
    final jsonList = await _storage.getJson(AppConstants.keyQuests);
    if (jsonList != null && jsonList is List && jsonList.isNotEmpty) {
      return jsonList
          .map((item) => QuestModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    // Return base activity quests if storage is empty
    return _activityCatalogService.getActivityQuests();
  }

  @override
  Future<List<QuestModel>> getQuestsForLocation(
    double userLat,
    double userLon, {
    double maxRadiusMeters = 5000.0,
  }) async {
    final existing = await getQuests();

    // Preserve any existing completed quest IDs so player progress is retained
    final completedIds = existing.where((q) => q.isCompleted).map((q) => q.id).toSet();

    // 1. Generate dynamic famous place quests connecting the user's location to important landmarks
    final locationQuests = await _placesDiscoveryService.generateFamousPlaceQuests(
      userLat: userLat,
      userLon: userLon,
      searchRadiusMeters: maxRadiusMeters,
      completedIds: completedIds,
    );

    // 2. Retrieve all activity quests across reading, writing, drawing, exercise, gaming, food, walking, etc.
    final activityQuests = _activityCatalogService.getActivityQuests().map((q) {
      return q.copyWith(isCompleted: completedIds.contains(q.id));
    }).map((q) => QuestModel.fromEntity(q)).toList();

    // 3. Combine both collections: Location quests + Activity quests
    final combined = <QuestModel>[
      ...locationQuests,
      ...activityQuests,
    ];

    await saveQuests(combined);
    return combined;
  }

  @override
  Future<void> saveQuests(List<QuestModel> quests) async {
    final jsonList = quests.map((q) => q.toJson()).toList();
    await _storage.saveJson(AppConstants.keyQuests, jsonList);
  }

  @override
  Future<QuestModel?> getQuestById(String id) async {
    final all = await getQuests();
    try {
      return all.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markCompleted(String id) async {
    final all = await getQuests();
    final updated = all.map((q) {
      if (q.id == id) {
        return q.copyWith(isCompleted: true);
      }
      return q;
    }).map((q) => QuestModel.fromEntity(q)).toList();

    await saveQuests(updated);
  }
}
