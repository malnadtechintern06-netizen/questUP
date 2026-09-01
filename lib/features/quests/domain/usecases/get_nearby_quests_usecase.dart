import '../entities/quest.dart';
import '../repositories/quest_repository.dart';

class GetNearbyQuestsUseCase {
  final QuestRepository _repository;

  const GetNearbyQuestsUseCase(this._repository);

  Future<List<Quest>> call({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 50000,
  }) async {
    return await _repository.getNearbyQuests(
      userLat: userLat,
      userLon: userLon,
      maxDistanceMeters: maxDistanceMeters,
    );
  }
}
