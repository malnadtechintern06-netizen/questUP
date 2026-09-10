import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/quest_calendar_entry_model.dart';

abstract class IQuestCalendarLocalDataSource {
  Future<List<QuestCalendarEntryModel>> getAllEntries();
  Future<void> saveEntry(QuestCalendarEntryModel entry);
  Future<void> saveAllEntries(List<QuestCalendarEntryModel> entries);
}

class QuestCalendarLocalDataSource implements IQuestCalendarLocalDataSource {
  final ILocalStorageService _storage;

  QuestCalendarLocalDataSource(this._storage);

  Future<String> _getActiveUserId() async {
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      if (authSession != null && authSession is Map<String, dynamic>) {
        return authSession['id']?.toString() ?? 'guest_player';
      }
    } catch (_) {}
    return 'guest_player';
  }

  @override
  Future<List<QuestCalendarEntryModel>> getAllEntries([String? targetUserId]) async {
    final userId = targetUserId ?? await _getActiveUserId();
    final userSpecificKey = 'questup_calendar_${userId}_v1';
    final jsonList = await _storage.getJson(userSpecificKey);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => QuestCalendarEntryModel.fromJson(item as Map<String, dynamic>))
          .where((e) => !e.id.startsWith('seed_'))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveEntry(QuestCalendarEntryModel entry) async {
    if (entry.id.startsWith('seed_')) return;
    final list = await getAllEntries();
    // Update existing entry if same id or quest on same day, otherwise add
    final index = list.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    await saveAllEntries(list);
  }

  @override
  Future<void> saveAllEntries(List<QuestCalendarEntryModel> entries) async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_calendar_${userId}_v1';
    final cleanEntries = entries.where((e) => !e.id.startsWith('seed_')).toList();
    final jsonList = cleanEntries.map((e) => e.toJson()).toList();
    await _storage.saveJson(userSpecificKey, jsonList);
  }
}
