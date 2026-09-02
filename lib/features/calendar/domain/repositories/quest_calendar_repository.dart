import '../entities/quest_calendar_entry.dart';

abstract class QuestCalendarRepository {
  Future<List<QuestCalendarEntry>> getAllEntries();
  Future<List<QuestCalendarEntry>> getEntriesForMonth(DateTime month);
  Future<List<QuestCalendarEntry>> getEntriesForDate(DateTime date);
  Future<void> recordQuestActivity({
    required String questId,
    required String questTitle,
    required String category,
    String difficulty = 'Medium',
    required QuestActivityStatus status,
    DateTime? timestamp,
    int xpReward = 0,
    int coinReward = 0,
    String? failureReason,
    String? verificationType,
  });
}
