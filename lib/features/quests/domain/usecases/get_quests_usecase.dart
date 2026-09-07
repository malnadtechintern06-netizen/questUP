import '../entities/quest.dart';
import '../repositories/quest_repository.dart';

class GetQuestsUseCase {
  final QuestRepository _repository;

  const GetQuestsUseCase(this._repository);

  Future<List<Quest>> call({
    double? userLat,
    double? userLon,
    String? userId,
  }) async {
    return await _repository.getQuests(
      userLat: userLat,
      userLon: userLon,
      userId: userId,
    );
  }
}
