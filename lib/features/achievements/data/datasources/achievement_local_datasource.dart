import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/achievement_model.dart';

abstract class IAchievementLocalDataSource {
  Future<List<AchievementModel>> getAchievements();
  Future<void> saveAchievements(List<AchievementModel> list);
}

class AchievementLocalDataSource implements IAchievementLocalDataSource {
  final ILocalStorageService _storage;

  AchievementLocalDataSource(this._storage);

  @override
  Future<List<AchievementModel>> getAchievements() async {
    final jsonList = await _storage.getJson(AppConstants.keyAchievements);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => AchievementModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final initial = _generateInitialAchievements();
    await saveAchievements(initial);
    return initial;
  }

  @override
  Future<void> saveAchievements(List<AchievementModel> list) async {
    final jsonList = list.map((a) => a.toJson()).toList();
    await _storage.saveJson(AppConstants.keyAchievements, jsonList);
  }

  List<AchievementModel> _generateInitialAchievements() {
    return [
      AchievementModel(
        id: 'badge_first_step',
        title: 'Novice Pioneer',
        description: 'Began your journey into the world of QuestUP.',
        iconKey: 'badge_compass',
        requiredQuestCount: 0,
        requiredLevel: 1,
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ),
      const AchievementModel(
        id: 'badge_first_quest',
        title: 'First Discovery',
        description: 'Successfully verify and complete your first real-world quest.',
        iconKey: 'badge_first_quest',
        requiredQuestCount: 1,
        requiredLevel: 1,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_pathfinder',
        title: 'Trail Blazer',
        description: 'Complete 3 real-world adventure quests.',
        iconKey: 'badge_trail',
        requiredQuestCount: 3,
        requiredLevel: 1,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_coin_hoarder',
        title: 'Bounty Hunter',
        description: 'Amass 500 or more quest coins in your vault.',
        iconKey: 'badge_coins',
        requiredQuestCount: 0,
        requiredCoins: 500,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_level_2',
        title: 'Adept Explorer',
        description: 'Advance your player rank to Level 2.',
        iconKey: 'badge_shield',
        requiredLevel: 2,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_legendary',
        title: 'Master of the Realm',
        description: 'Reach Level 3 and become a certified master explorer.',
        iconKey: 'badge_crown',
        requiredLevel: 3,
        isUnlocked: false,
      ),
    ];
  }
}
