import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/quest_completion_model.dart';

abstract class IVerificationLocalDataSource {
  Future<List<QuestCompletionModel>> getCompletions();
  Future<void> saveCompletion(QuestCompletionModel completion);
}

class VerificationLocalDataSource implements IVerificationLocalDataSource {
  final ILocalStorageService _storage;

  VerificationLocalDataSource(this._storage);

  @override
  Future<List<QuestCompletionModel>> getCompletions() async {
    final jsonList = await _storage.getJson(AppConstants.keyCompletions);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => QuestCompletionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveCompletion(QuestCompletionModel completion) async {
    final list = await getCompletions();
    list.add(completion);
    final jsonList = list.map((c) => c.toJson()).toList();
    await _storage.saveJson(AppConstants.keyCompletions, jsonList);
  }
}
