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

  Future<Set<String>> _getActiveUserCompletedQuestIds() async {
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      String? userId;
      if (authSession != null && authSession is Map<String, dynamic>) {
        userId = authSession['id']?.toString();
      }

      final targetKey = userId != null ? 'questup_user_profile_${userId}_v1' : AppConstants.keyUserProfile;
      final profileJson = await _storage.getJson(targetKey);
      if (profileJson != null && profileJson is Map<String, dynamic>) {
        final completedList = profileJson['completedQuestIds'];
        if (completedList is List) {
          return completedList.map((e) => e.toString()).toSet();
        }
      }
    } catch (_) {}
    return <String>{};
  }

  @override
  Future<List<QuestModel>> getQuests() async {
    final completedIds = await _getActiveUserCompletedQuestIds();
    final jsonList = await _storage.getJson(AppConstants.keyQuests);
    if (jsonList != null && jsonList is List && jsonList.isNotEmpty) {
      return jsonList
          .map((item) => QuestModel.fromJson(item as Map<String, dynamic>))
          .map((q) => QuestModel.fromEntity(q.copyWith(isCompleted: completedIds.contains(q.id))))
          .toList();
    }
    // Return base activity quests if storage is empty
    return _activityCatalogService.getActivityQuests().map((q) {
      return q.copyWith(isCompleted: completedIds.contains(q.id));
    }).map((q) => QuestModel.fromEntity(q)).toList();
  }

  @override
  Future<List<QuestModel>> getQuestsForLocation(
    double userLat,
    double userLon, {
    double maxRadiusMeters = 5000.0,
  }) async {
    final completedIds = await _getActiveUserCompletedQuestIds();

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
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      String? userId;
      if (authSession != null && authSession is Map<String, dynamic>) {
        userId = authSession['id']?.toString();
      }

      final targetKey = userId != null ? 'questup_user_profile_${userId}_v1' : AppConstants.keyUserProfile;
      final profileJson = await _storage.getJson(targetKey);
      if (profileJson != null && profileJson is Map<String, dynamic>) {
        final completedList = List<String>.from(
          (profileJson['completedQuestIds'] as List?)?.map((e) => e.toString()) ?? const [],
        );
        if (!completedList.contains(id)) {
          completedList.add(id);
          profileJson['completedQuestIds'] = completedList;
          await _storage.saveJson(targetKey, profileJson);
          await _storage.saveJson(AppConstants.keyUserProfile, profileJson);
        }
      }
    } catch (_) {}
  }
}
