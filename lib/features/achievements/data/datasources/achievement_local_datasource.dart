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

  Future<String> _getActiveUserId() async {
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      if (authSession != null && authSession is Map<String, dynamic>) {
        return authSession['id']?.toString() ?? 'guest_player';
      }
    } catch (_) {}
    return 'guest_player';
  }

  @override
  Future<List<AchievementModel>> getAchievements([String? targetUserId]) async {
    final initial = _generateInitialAchievements();
    final userId = targetUserId ?? await _getActiveUserId();
    final userSpecificKey = 'questup_achievements_${userId}_v1';

    final jsonList = await _storage.getJson(userSpecificKey);
    if (jsonList != null && jsonList is List) {
      final savedList = jsonList
          .map((item) => AchievementModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Merge saved unlock states with the full initial list so new hardcore badges always appear
      final savedMap = {for (var a in savedList) a.id: a};
      final merged = initial.map<AchievementModel>((init) {
        if (savedMap.containsKey(init.id)) {
          final saved = savedMap[init.id]!;
          return AchievementModel.fromEntity(init.copyWith(
            isUnlocked: saved.isUnlocked,
            unlockedAt: saved.unlockedAt,
          ));
        }
        return init;
      }).toList();

      return merged;
    }

    await saveAchievements(initial);
    return initial;
  }

  @override
  Future<void> saveAchievements(List<AchievementModel> list) async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_achievements_${userId}_v1';
    final jsonList = list.map((a) => a.toJson()).toList();
    await _storage.saveJson(userSpecificKey, jsonList);
    await _storage.saveJson(AppConstants.keyAchievements, jsonList);
  }

  List<AchievementModel> _generateInitialAchievements() {
    return [
      // 1. Starter & Novice Badges
      AchievementModel(
        id: 'badge_first_step',
        title: 'Novice Pioneer',
        description: 'Began your journey into the world of QuestUP.',
        iconKey: 'badge_compass',
        tier: 'NOVICE',
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
        tier: 'NOVICE',
        requiredQuestCount: 1,
        requiredLevel: 1,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_pathfinder',
        title: 'Trail Blazer',
        description: 'Complete 3 real-world adventure quests.',
        iconKey: 'badge_trail',
        tier: 'ADEPT',
        requiredQuestCount: 3,
        requiredLevel: 1,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_coin_hoarder',
        title: 'Bounty Hunter',
        description: 'Amass 500 or more quest coins in your vault.',
        iconKey: 'badge_coins',
        tier: 'ADEPT',
        requiredQuestCount: 0,
        requiredCoins: 500,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_level_2',
        title: 'Adept Explorer',
        description: 'Advance your player rank to Level 2.',
        iconKey: 'badge_shield',
        tier: 'ADEPT',
        requiredLevel: 2,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_legendary',
        title: 'Master of the Realm',
        description: 'Reach Level 3 and become a certified master explorer.',
        iconKey: 'badge_crown',
        tier: 'MASTER',
        requiredLevel: 3,
        isUnlocked: false,
      ),

      // 7 Extra Hardcore Badges
      const AchievementModel(
        id: 'badge_grandmaster_explorer',
        title: 'Century Globetrotter',
        description: 'Conquer 15 verified real-world waypoint and adventure quests.',
        iconKey: 'badge_globe_conqueror',
        tier: 'HARDCORE',
        requiredQuestCount: 15,
        requiredLevel: 3,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_dragon_vault',
        title: "Dragon's Treasury",
        description: 'Amass an immense fortune of 2,500+ gold coins in your explorer vault.',
        iconKey: 'badge_dragon_gold',
        tier: 'HARDCORE',
        requiredCoins: 2500,
        requiredLevel: 2,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_iron_marathoner',
        title: 'Iron Marathoner',
        description: 'Complete 10 walking or endurance distance missions with relentless stamina.',
        iconKey: 'badge_iron_legs',
        tier: 'HARDCORE',
        requiredQuestCount: 10,
        requiredLevel: 3,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_photographic_eye',
        title: 'Eagle Eye Spotter',
        description: 'Reach Level 4 with 8 verified real-time photo landmark discoveries.',
        iconKey: 'badge_eagle_eye',
        tier: 'HARDCORE',
        requiredQuestCount: 8,
        requiredLevel: 4,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_shadow_puzzle_master',
        title: 'Enigma Slayer',
        description: 'Decipher 6 intricate mystery folklore riddles and hidden secrets.',
        iconKey: 'badge_enigma',
        tier: 'HARDCORE',
        requiredQuestCount: 6,
        requiredLevel: 2,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_apex_predator',
        title: 'Apex Titan',
        description: 'Ascend to Level 5 and solidify your dominance as an elite master pioneer.',
        iconKey: 'badge_apex_titan',
        tier: 'HARDCORE',
        requiredLevel: 5,
        isUnlocked: false,
      ),
      const AchievementModel(
        id: 'badge_immortal_legend',
        title: 'Immortal Mythic',
        description: 'The ultimate pinnacle achievement: Reach Level 8 and hoard 5,000 gold coins.',
        iconKey: 'badge_immortal_mythic',
        tier: 'MYTHIC',
        requiredLevel: 8,
        requiredCoins: 5000,
        isUnlocked: false,
      ),
    ];
  }
}
