import '../../domain/entities/achievement.dart';
import '../../domain/repositories/achievement_repository.dart';
import '../datasources/achievement_local_datasource.dart';
import '../models/achievement_model.dart';

class AchievementRepositoryImpl implements AchievementRepository {
  final IAchievementLocalDataSource _localDataSource;

  AchievementRepositoryImpl(this._localDataSource);

  @override
  Future<List<Achievement>> getAchievements() async {
    return await _localDataSource.getAchievements();
  }

  @override
  Future<Achievement?> evaluateAndUnlockAchievements({
    required int completedCount,
    required int currentLevel,
    required int totalCoins,
  }) async {
    final achievements = await _localDataSource.getAchievements();
    Achievement? newlyUnlocked;
    final List<AchievementModel> updatedList = [];

    for (final a in achievements) {
      if (!a.isUnlocked) {
        bool shouldUnlock = false;

        if (a.requiredQuestCount > 0 && completedCount >= a.requiredQuestCount) {
          shouldUnlock = true;
        } else if (a.requiredLevel > 1 && currentLevel >= a.requiredLevel) {
          shouldUnlock = true;
        } else if (a.requiredCoins > 0 && totalCoins >= a.requiredCoins) {
          shouldUnlock = true;
        }

        if (shouldUnlock) {
          final unlocked = a.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          );
          newlyUnlocked ??= unlocked;
          updatedList.add(AchievementModel.fromEntity(unlocked));
          continue;
        }
      }
      updatedList.add(AchievementModel.fromEntity(a));
    }

    if (newlyUnlocked != null) {
      await _localDataSource.saveAchievements(updatedList);
    }

    return newlyUnlocked;
  }
}
