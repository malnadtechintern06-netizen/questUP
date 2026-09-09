import '../entities/quest.dart';
import '../entities/shared_quest.dart';

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
  Future<bool> shareQuestWithFriend({
    required String questId,
    required String questTitle,
    required String senderId,
    required String senderName,
    required String senderTag,
    required String receiverId,
  });
  Future<List<SharedQuest>> getSharedQuests({required String userId});
}
