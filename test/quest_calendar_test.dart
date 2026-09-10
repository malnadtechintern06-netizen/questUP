import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/calendar/data/datasources/quest_calendar_local_datasource.dart';
import 'package:quest_up/features/calendar/data/repositories/quest_calendar_repository_impl.dart';
import 'package:quest_up/features/calendar/domain/entities/quest_calendar_entry.dart';
import 'package:quest_up/features/calendar/presentation/providers/quest_calendar_providers.dart';
import 'package:quest_up/features/profile/data/datasources/user_local_datasource.dart';
import 'package:quest_up/features/profile/data/repositories/user_repository_impl.dart';

class MockMemoryLocalStorageService implements ILocalStorageService {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<dynamic> getJson(String key) async => _store[key];

  @override
  Future<String?> getString(String key) async => _store[key] as String?;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> saveJson(String key, dynamic value) async => _store[key] = value;

  @override
  Future<void> saveString(String key, String value) async => _store[key] = value;
}

void main() {
  group('Quest Activity Calendar - Registration Date Anchoring & Clean State Tests', () {
    late MockMemoryLocalStorageService storage;
    late AuthMySqlDataSource authDataSource;
    late UserLocalDataSource userLocalDataSource;
    late UserRepositoryImpl userRepository;
    late QuestCalendarLocalDataSource calendarLocalDataSource;
    late QuestCalendarRepositoryImpl calendarRepository;

    setUp(() {
      storage = MockMemoryLocalStorageService();
      authDataSource = AuthMySqlDataSource(storage);
      userLocalDataSource = UserLocalDataSource(storage);
      userRepository = UserRepositoryImpl(userLocalDataSource);
      calendarLocalDataSource = QuestCalendarLocalDataSource(storage);
      calendarRepository = QuestCalendarRepositoryImpl(
        localDataSource: calendarLocalDataSource,
        userRepository: userRepository,
      );
    });

    test('New registered account has 0 calendar entries and no sample seed history', () async {
      // 1. Register new user
      final user = await authDataSource.register(
        name: 'Sujan Explorer',
        email: 'sujan.test@questup.app',
        password: 'Password123!',
      );
      expect(user.id, isNotEmpty);

      // 2. Fetch all calendar entries
      final entries = await calendarRepository.getAllEntries();
      expect(entries, isEmpty, reason: 'New user must have 0 calendar entries, no seed history');

      // 3. Check dates in the past (e.g. 1 to 7 days ago)
      final now = DateTime.now();
      for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
        final pastDate = now.subtract(Duration(days: dayOffset));
        final dayEntries = await calendarRepository.getEntriesForDate(pastDate);
        expect(dayEntries, isEmpty, reason: 'Days before registration date must have 0 entries');
      }
    });

    test('Calendar monthStatusMap displays no dots for dates before registration date', () async {
      // User registered today
      final now = DateTime.now();
      await authDataSource.register(
        name: 'Maya Explorer',
        email: 'maya.test@questup.app',
        password: 'Password123!',
      );

      final state = QuestCalendarState(
        selectedDate: now,
        currentMonth: DateTime(now.year, now.month),
        userJoinedAt: now,
        monthEntries: const [],
      );

      expect(state.monthStatusMap, isEmpty);

      // Even if legacy entries exist with timestamp before joinedAt, monthStatusMap filters them
      final stateWithPreRegEntries = QuestCalendarState(
        selectedDate: now,
        currentMonth: DateTime(now.year, now.month),
        userJoinedAt: now,
        monthEntries: [
          QuestCalendarEntry(
            id: 'legacy_1',
            questId: 'q_old',
            questTitle: 'Old Quest',
            category: 'Landmark',
            difficulty: 'Easy',
            status: QuestActivityStatus.completed,
            timestamp: now.subtract(const Duration(days: 3)),
          ),
        ],
      );

      expect(stateWithPreRegEntries.monthStatusMap, isEmpty,
          reason: 'Pre-registration entries must not appear in monthStatusMap');
    });

    test('Recorded activities on or after registration day are properly logged and retrieved', () async {
      final user = await authDataSource.register(
        name: 'Rohan Scout',
        email: 'rohan.test@questup.app',
        password: 'Password123!',
      );

      final now = DateTime.now();

      // Record a completed quest today
      await calendarRepository.recordQuestActivity(
        questId: 'quest_hosa_fort',
        questTitle: 'Explore Ancient Hosanagara Fort',
        category: 'Landmark',
        difficulty: 'Medium',
        status: QuestActivityStatus.completed,
        xpReward: 150,
        coinReward: 75,
        timestamp: now,
      );

      // Record a failed quest today
      await calendarRepository.recordQuestActivity(
        questId: 'quest_waterfall',
        questTitle: 'Jog Falls Mist Trail',
        category: 'Nature',
        difficulty: 'Hard',
        status: QuestActivityStatus.failed,
        failureReason: 'Geofence radius exceeded',
        xpReward: 200,
        coinReward: 100,
        timestamp: now,
      );

      final all = await calendarRepository.getAllEntries();
      expect(all.length, equals(2));

      final todayEntries = await calendarRepository.getEntriesForDate(now);
      expect(todayEntries.length, equals(2));
      expect(todayEntries.any((e) => e.isCompleted && e.questId == 'quest_hosa_fort'), isTrue);
      expect(todayEntries.any((e) => e.isFailed && e.questId == 'quest_waterfall'), isTrue);

      // Check monthStatusMap has completed and failed dots for today
      final state = QuestCalendarState(
        selectedDate: now,
        currentMonth: DateTime(now.year, now.month),
        userJoinedAt: user.createdAt,
        monthEntries: all,
        selectedDateEntries: todayEntries,
      );

      final todayStatuses = state.monthStatusMap[now.day];
      expect(todayStatuses, isNotNull);
      expect(todayStatuses!, contains(QuestActivityStatus.completed));
      expect(todayStatuses, contains(QuestActivityStatus.failed));
    });

    test('Multi-account isolation: User A entries do not pollute User B calendar', () async {
      // 1. Register User A and record activity
      final userA = await authDataSource.register(
        name: 'User A',
        email: 'usera@questup.app',
        password: 'Password123!',
      );
      expect(userA.id, isNotEmpty);

      await calendarRepository.recordQuestActivity(
        questId: 'quest_a_1',
        questTitle: 'User A Landmark Quest',
        category: 'Landmark',
        status: QuestActivityStatus.completed,
        timestamp: DateTime.now(),
      );

      final entriesA = await calendarRepository.getAllEntries();
      expect(entriesA.length, equals(1));

      // 2. Logout User A and Register User B
      await authDataSource.logout();

      final userB = await authDataSource.register(
        name: 'User B',
        email: 'userb@questup.app',
        password: 'Password123!',
      );
      expect(userB.id, isNotEmpty);

      // User B must have 0 entries
      final entriesB = await calendarRepository.getAllEntries();
      expect(entriesB, isEmpty, reason: 'User B must not see User A calendar records');
    });
  });
}
