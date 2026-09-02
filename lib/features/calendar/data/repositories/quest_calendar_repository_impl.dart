import 'package:uuid/uuid.dart';
import '../../../quests/domain/repositories/quest_repository.dart';
import '../../domain/entities/quest_calendar_entry.dart';
import '../../domain/repositories/quest_calendar_repository.dart';
import '../datasources/quest_calendar_local_datasource.dart';
import '../models/quest_calendar_entry_model.dart';

class QuestCalendarRepositoryImpl implements QuestCalendarRepository {
  final IQuestCalendarLocalDataSource localDataSource;
  final QuestRepository? questRepository;
  final Uuid _uuid = const Uuid();

  QuestCalendarRepositoryImpl({
    required this.localDataSource,
    this.questRepository,
  });

  @override
  Future<List<QuestCalendarEntry>> getAllEntries() async {
    var entries = await localDataSource.getAllEntries();
    if (entries.isEmpty) {
      entries = _generateInitialSampleHistory();
      await localDataSource.saveAllEntries(entries);
    }
    return entries;
  }

  @override
  Future<List<QuestCalendarEntry>> getEntriesForMonth(DateTime month) async {
    final all = await getAllEntries();
    return all.where((e) =>
        e.timestamp.year == month.year && e.timestamp.month == month.month).toList();
  }

  @override
  Future<List<QuestCalendarEntry>> getEntriesForDate(DateTime date) async {
    final all = await getAllEntries();
    final dayEntries = all.where((e) =>
        e.timestamp.year == date.year &&
        e.timestamp.month == date.month &&
        e.timestamp.day == date.day).toList();

    // If querying today and questRepository is provided, merge with any unattempted active quests
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday && questRepository != null) {
      try {
        final allQuests = await questRepository!.getQuests();
        final attemptedQuestIds = dayEntries.map((e) => e.questId).toSet();

        for (final q in allQuests) {
          if (!attemptedQuestIds.contains(q.id)) {
            dayEntries.add(
              QuestCalendarEntry(
                id: 'active_${q.id}',
                questId: q.id,
                questTitle: q.title,
                category: q.category.name,
                difficulty: q.difficulty.name,
                status: q.isCompleted
                    ? QuestActivityStatus.completed
                    : QuestActivityStatus.incomplete,
                timestamp: now,
                xpReward: q.xpReward,
                coinReward: q.coinReward,
              ),
            );
          }
        }
      } catch (_) {}
    }

    return dayEntries;
  }

  @override
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
  }) async {
    final entry = QuestCalendarEntryModel(
      id: _uuid.v4(),
      questId: questId,
      questTitle: questTitle,
      category: category,
      difficulty: difficulty,
      status: status,
      timestamp: timestamp ?? DateTime.now(),
      xpReward: xpReward,
      coinReward: coinReward,
      failureReason: failureReason,
      verificationType: verificationType,
    );

    await localDataSource.saveEntry(entry);
  }

  List<QuestCalendarEntryModel> _generateInitialSampleHistory() {
    final now = DateTime.now();
    return [
      QuestCalendarEntryModel(
        id: 'seed_comp_1',
        questId: 'q_hosa_bus_stand',
        questTitle: 'Visit Hosanagara Bus Station',
        category: 'Landmark',
        difficulty: 'Easy',
        status: QuestActivityStatus.completed,
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        xpReward: 50,
        coinReward: 25,
      ),
      QuestCalendarEntryModel(
        id: 'seed_fail_1',
        questId: 'q_sharavathi_trail',
        questTitle: 'Sharavathi River View Walk',
        category: 'Nature',
        difficulty: 'Medium',
        status: QuestActivityStatus.failed,
        timestamp: now.subtract(const Duration(days: 2, hours: 4)),
        xpReward: 120,
        coinReward: 60,
        failureReason: 'GPS geofence radius exceeded (210m away)',
      ),
      QuestCalendarEntryModel(
        id: 'seed_comp_2',
        questId: 'q_kodachadri_trek',
        questTitle: 'Kodachadri Peak Trail',
        category: 'Fitness',
        difficulty: 'Hard',
        status: QuestActivityStatus.completed,
        timestamp: now.subtract(const Duration(days: 3, hours: 5)),
        xpReward: 300,
        coinReward: 150,
      ),
      QuestCalendarEntryModel(
        id: 'seed_inc_1',
        questId: 'q_local_writing_lore',
        questTitle: 'Write 100 Words on Hosanagara Heritage',
        category: 'Writing',
        difficulty: 'Easy',
        status: QuestActivityStatus.incomplete,
        timestamp: now.subtract(const Duration(days: 4)),
        xpReward: 80,
        coinReward: 40,
      ),
    ];
  }
}
