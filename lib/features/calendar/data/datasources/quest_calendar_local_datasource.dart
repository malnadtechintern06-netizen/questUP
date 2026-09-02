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

  @override
  Future<List<QuestCalendarEntryModel>> getAllEntries() async {
    final jsonList = await _storage.getJson(AppConstants.keyCalendarEntries);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => QuestCalendarEntryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveEntry(QuestCalendarEntryModel entry) async {
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
    final jsonList = entries.map((e) => e.toJson()).toList();
    await _storage.saveJson(AppConstants.keyCalendarEntries, jsonList);
  }
}
