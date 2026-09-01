import '../entities/achievement.dart';

abstract class AchievementRepository {
  Future<List<Achievement>> getAchievements();
  Future<Achievement?> evaluateAndUnlockAchievements({
    required int completedCount,
    required int currentLevel,
    required int totalCoins,
  });
}
