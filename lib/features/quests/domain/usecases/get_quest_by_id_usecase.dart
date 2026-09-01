import '../entities/quest.dart';
import '../repositories/quest_repository.dart';

class GetQuestByIdUseCase {
  final QuestRepository _repository;

  const GetQuestByIdUseCase(this._repository);

  Future<Quest?> call(String id) async {
    return await _repository.getQuestById(id);
  }
}
