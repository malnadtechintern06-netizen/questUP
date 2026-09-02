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

  int _getTierWeight(String tier) {
    switch (tier.toUpperCase()) {
      case 'MYTHIC':
        return 4;
      case 'HARDCORE':
        return 3;
      case 'MASTER':
        return 2;
      case 'ADEPT':
        return 1;
      default:
        return 0;
    }
  }

  bool _isMorePrestigious(Achievement a, Achievement b) {
    final weightA = _getTierWeight(a.tier);
    final weightB = _getTierWeight(b.tier);
    if (weightA != weightB) return weightA > weightB;
    if (a.requiredLevel != b.requiredLevel) return a.requiredLevel > b.requiredLevel;
    if (a.requiredQuestCount != b.requiredQuestCount) return a.requiredQuestCount > b.requiredQuestCount;
    return a.requiredCoins > b.requiredCoins;
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

        final hasQuestReq = a.requiredQuestCount > 0;
        final hasLevelReq = a.requiredLevel > 1;
        final hasCoinReq = a.requiredCoins > 0;

        if (hasQuestReq || hasLevelReq || hasCoinReq) {
          final meetsQuest = !hasQuestReq || completedCount >= a.requiredQuestCount;
          final meetsLevel = !hasLevelReq || currentLevel >= a.requiredLevel;
          final meetsCoins = !hasCoinReq || totalCoins >= a.requiredCoins;

          if (meetsQuest && meetsLevel && meetsCoins) {
            shouldUnlock = true;
          }
        }

        if (shouldUnlock) {
          final unlocked = a.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          );
          if (newlyUnlocked == null || _isMorePrestigious(unlocked, newlyUnlocked)) {
            newlyUnlocked = unlocked;
          }
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
