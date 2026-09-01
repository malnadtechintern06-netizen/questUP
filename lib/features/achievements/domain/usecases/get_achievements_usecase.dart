import '../entities/achievement.dart';
import '../repositories/achievement_repository.dart';

class GetAchievementsUseCase {
  final AchievementRepository _repository;

  const GetAchievementsUseCase(this._repository);

  Future<List<Achievement>> call() async {
    return await _repository.getAchievements();
  }
}
