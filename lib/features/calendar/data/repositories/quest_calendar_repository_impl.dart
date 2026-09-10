import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../../../app/config/mysql_config.dart';
import '../../../profile/domain/repositories/user_repository.dart';
import '../../../quests/domain/repositories/quest_repository.dart';
import '../../domain/entities/quest_calendar_entry.dart';
import '../../domain/repositories/quest_calendar_repository.dart';
import '../datasources/quest_calendar_local_datasource.dart';
import '../models/quest_calendar_entry_model.dart';

class QuestCalendarRepositoryImpl implements QuestCalendarRepository {
  final IQuestCalendarLocalDataSource localDataSource;
  final QuestRepository? questRepository;
  final UserRepository? userRepository;
  final Uuid _uuid = const Uuid();

  QuestCalendarRepositoryImpl({
    required this.localDataSource,
    this.questRepository,
    this.userRepository,
  });

  @override
  Future<List<QuestCalendarEntry>> getAllEntries() async {
    var entries = await localDataSource.getAllEntries();
    // Filter out any legacy sample entries
    var cleanEntries = entries.where((e) => !e.id.startsWith('seed_')).toList();

    // If user profile is available, filter entries strictly on or after registration date
    if (userRepository != null) {
      try {
        final profile = await userRepository!.getUserProfile();
        final regDate = DateTime(
          profile.joinedAt.year,
          profile.joinedAt.month,
          profile.joinedAt.day,
        );
        cleanEntries = cleanEntries.where((e) {
          final entryDate = DateTime(
            e.timestamp.year,
            e.timestamp.month,
            e.timestamp.day,
          );
          return !entryDate.isBefore(regDate);
        }).toList();
      } catch (_) {}
    }

    return cleanEntries;
  }

  @override
  Future<List<QuestCalendarEntry>> getEntriesForMonth(DateTime month) async {
    final all = await getAllEntries();
    return all.where((e) =>
        e.timestamp.year == month.year && e.timestamp.month == month.month).toList();
  }

  @override
  Future<List<QuestCalendarEntry>> getEntriesForDate(DateTime date) async {
    DateTime? regDay;
    if (userRepository != null) {
      try {
        final profile = await userRepository!.getUserProfile();
        regDay = DateTime(
          profile.joinedAt.year,
          profile.joinedAt.month,
          profile.joinedAt.day,
        );
      } catch (_) {}
    }

    final targetDay = DateTime(date.year, date.month, date.day);

    // If querying a date prior to the user's account registration, return empty list
    if (regDay != null && targetDay.isBefore(regDay)) {
      return [];
    }

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

    // 1. Save locally for instant UI update & offline reliability
    await localDataSource.saveEntry(entry);

    // 2. Asynchronously sync to Backend MySQL activity_logs table for phpMyAdmin visibility
    _syncActivityToBackend(entry);
  }

  void _syncActivityToBackend(QuestCalendarEntry entry) {
    Future(() async {
      try {
        String? userId;
        if (userRepository != null) {
          try {
            final profile = await userRepository!.getUserProfile();
            userId = profile.id;
          } catch (_) {}
        }

        final payload = jsonEncode({
          'user_id': userId,
          'quest_id': entry.questId,
          'quest_title': entry.questTitle,
          'category': entry.category,
          'difficulty': entry.difficulty,
          'status': entry.status.name,
          'xp_reward': entry.xpReward,
          'coin_reward': entry.coinReward,
          'failure_reason': entry.failureReason,
          'verification_type': entry.verificationType,
          'action': entry.isCompleted
              ? 'quest_completed'
              : (entry.isFailed ? 'quest_failed' : 'quest_activity'),
        });

        for (final base in MySqlConfig.apiBaseUrls) {
          HttpClient? client;
          try {
            final uri = Uri.parse('$base/activity/record.php');
            client = HttpClient()
              ..connectionTimeout = const Duration(milliseconds: 2500)
              ..badCertificateCallback = ((cert, host, port) => true);

            final req = await client.postUrl(uri);
            req.headers.set('Content-Type', 'application/json; charset=utf-8');
            req.headers.set('Accept', 'application/json');
            req.write(payload);

            final res = await req.close().timeout(const Duration(milliseconds: 3000));
            if (res.statusCode == 200 || res.statusCode == 201) {
              break;
            }
          } catch (_) {
          } finally {
            client?.close(force: true);
          }
        }
      } catch (_) {}
    });
  }
}
