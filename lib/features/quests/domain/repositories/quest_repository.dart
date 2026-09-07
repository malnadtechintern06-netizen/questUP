import '../entities/quest.dart';

abstract class QuestRepository {
  Future<List<Quest>> getQuests({
    double? userLat,
    double? userLon,
    String? userId,
  });
  Future<List<Quest>> getNearbyQuests({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 10000, // 10km
    String? userId,
  });
  Future<Quest?> getQuestById(String id);
  Future<void> markQuestCompleted(String id);
}
