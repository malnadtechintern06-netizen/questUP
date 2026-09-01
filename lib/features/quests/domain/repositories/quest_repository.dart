import '../entities/quest.dart';

abstract class QuestRepository {
  Future<List<Quest>> getQuests();
  Future<List<Quest>> getNearbyQuests({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 50000, // 50km
  });
  Future<Quest?> getQuestById(String id);
  Future<void> markQuestCompleted(String id);
}
