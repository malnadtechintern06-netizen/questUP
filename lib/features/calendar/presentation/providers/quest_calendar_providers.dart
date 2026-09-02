import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/profile/presentation/providers/user_providers.dart';
import '../../../../features/quests/presentation/providers/quest_providers.dart';
import '../../data/datasources/quest_calendar_local_datasource.dart';
import '../../data/repositories/quest_calendar_repository_impl.dart';
import '../../domain/entities/quest_calendar_entry.dart';
import '../../domain/repositories/quest_calendar_repository.dart';

final questCalendarLocalDataSourceProvider =
    Provider<IQuestCalendarLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return QuestCalendarLocalDataSource(storage);
});

final questCalendarRepositoryProvider =
    Provider<QuestCalendarRepository>((ref) {
  final localData = ref.watch(questCalendarLocalDataSourceProvider);
  final questRepo = ref.watch(questRepositoryProvider);
  return QuestCalendarRepositoryImpl(
    localDataSource: localData,
    questRepository: questRepo,
  );
});

class QuestCalendarState {
  final DateTime selectedDate;
  final DateTime currentMonth;
  final bool isLoading;
  final List<QuestCalendarEntry> monthEntries;
  final List<QuestCalendarEntry> selectedDateEntries;
  final String? error;

  QuestCalendarState({
    required this.selectedDate,
    required this.currentMonth,
    this.isLoading = false,
    this.monthEntries = const [],
    this.selectedDateEntries = const [],
    this.error,
  });

  // Daily statistics for the currently selected date
  int get dailyCompletedCount =>
      selectedDateEntries.where((e) => e.isCompleted).length;
  int get dailyIncompleteCount =>
      selectedDateEntries.where((e) => e.isIncomplete).length;
  int get dailyFailedCount =>
      selectedDateEntries.where((e) => e.isFailed).length;
  int get dailyTotalCount => selectedDateEntries.length;

  // Total XP & Coins earned on selected date
  int get dailyXpEarned => selectedDateEntries
      .where((e) => e.isCompleted)
      .fold(0, (sum, e) => sum + e.xpReward);
  int get dailyCoinsEarned => selectedDateEntries
      .where((e) => e.isCompleted)
      .fold(0, (sum, e) => sum + e.coinReward);

  // Helper map for day status dots: day of month -> status list
  Map<int, List<QuestActivityStatus>> get monthStatusMap {
    final map = <int, List<QuestActivityStatus>>{};
    for (final e in monthEntries) {
      if (e.timestamp.year == currentMonth.year &&
          e.timestamp.month == currentMonth.month) {
        final day = e.timestamp.day;
        map.putIfAbsent(day, () => []);
        if (!map[day]!.contains(e.status)) {
          map[day]!.add(e.status);
        }
      }
    }
    return map;
  }

  QuestCalendarState copyWith({
    DateTime? selectedDate,
    DateTime? currentMonth,
    bool? isLoading,
    List<QuestCalendarEntry>? monthEntries,
    List<QuestCalendarEntry>? selectedDateEntries,
    String? error,
  }) {
    return QuestCalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      currentMonth: currentMonth ?? this.currentMonth,
      isLoading: isLoading ?? this.isLoading,
      monthEntries: monthEntries ?? this.monthEntries,
      selectedDateEntries: selectedDateEntries ?? this.selectedDateEntries,
      error: error,
    );
  }
}

class QuestCalendarNotifier extends StateNotifier<QuestCalendarState> {
  final QuestCalendarRepository _repository;

  QuestCalendarNotifier(this._repository)
      : super(QuestCalendarState(
          selectedDate: DateTime.now(),
          currentMonth: DateTime(DateTime.now().year, DateTime.now().month),
        )) {
    loadCalendarData();
  }

  Future<void> loadCalendarData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final monthData = await _repository.getEntriesForMonth(state.currentMonth);
      final dayData = await _repository.getEntriesForDate(state.selectedDate);

      state = state.copyWith(
        isLoading: false,
        monthEntries: monthData,
        selectedDateEntries: dayData,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async => loadCalendarData();

  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(selectedDate: date, isLoading: true);
    try {
      final dayData = await _repository.getEntriesForDate(date);
      state = state.copyWith(selectedDateEntries: dayData, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> changeMonth(int monthOffset) async {
    final nextMonth = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + monthOffset,
    );
    state = state.copyWith(currentMonth: nextMonth, isLoading: true);
    try {
      final monthData = await _repository.getEntriesForMonth(nextMonth);
      state = state.copyWith(monthEntries: monthData, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> recordActivity({
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
    await _repository.recordQuestActivity(
      questId: questId,
      questTitle: questTitle,
      category: category,
      difficulty: difficulty,
      status: status,
      timestamp: timestamp,
      xpReward: xpReward,
      coinReward: coinReward,
      failureReason: failureReason,
      verificationType: verificationType,
    );
    await loadCalendarData();
  }
}

final questCalendarNotifierProvider =
    StateNotifierProvider<QuestCalendarNotifier, QuestCalendarState>((ref) {
  final repo = ref.watch(questCalendarRepositoryProvider);
  return QuestCalendarNotifier(repo);
});
