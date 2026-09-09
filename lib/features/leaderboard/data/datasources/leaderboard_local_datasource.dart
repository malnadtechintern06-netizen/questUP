import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/leaderboard_entry_model.dart';

abstract class ILeaderboardLocalDataSource {
  Future<List<LeaderboardEntryModel>> getCompetitors();
  Future<List<LeaderboardEntryModel>> getWeeklyCompetitors();
}

class LeaderboardLocalDataSource implements ILeaderboardLocalDataSource {
  final ILocalStorageService _storage;

  LeaderboardLocalDataSource(this._storage);

  @override
  Future<List<LeaderboardEntryModel>> getCompetitors() async {
    final jsonList = await _storage.getJson(AppConstants.keyLeaderboard);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => LeaderboardEntryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final initial = _generateCompetitors();
    final serialized = initial.map((e) => e.toJson()).toList();
    await _storage.saveJson(AppConstants.keyLeaderboard, serialized);
    return initial;
  }

  @override
  Future<List<LeaderboardEntryModel>> getWeeklyCompetitors() async {
    final weeklyKey = '${AppConstants.keyLeaderboard}_weekly';
    final jsonList = await _storage.getJson(weeklyKey);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => LeaderboardEntryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final initial = _generateWeeklyCompetitors();
    final serialized = initial.map((e) => e.toJson()).toList();
    await _storage.saveJson(weeklyKey, serialized);
    return initial;
  }

  List<LeaderboardEntryModel> _generateWeeklyCompetitors() {
    return const [
      LeaderboardEntryModel(
        userId: 'comp_1',
        userName: 'Elena Shadowstride',
        avatarKey: 'avatar_mystic_sage',
        rank: 1,
        level: 6,
        xp: 520,
        completedQuestsCount: 4,
      ),
      LeaderboardEntryModel(
        userId: 'comp_2',
        userName: 'Kai Horizon',
        avatarKey: 'avatar_sky_pilot',
        rank: 2,
        level: 5,
        xp: 410,
        completedQuestsCount: 3,
      ),
      LeaderboardEntryModel(
        userId: 'comp_3',
        userName: 'Marcus Storm',
        avatarKey: 'avatar_fire_trail',
        rank: 3,
        level: 4,
        xp: 310,
        completedQuestsCount: 2,
      ),
      LeaderboardEntryModel(
        userId: 'comp_4',
        userName: 'Aria Silverleaf',
        avatarKey: 'avatar_ranger',
        rank: 4,
        level: 3,
        xp: 200,
        completedQuestsCount: 2,
      ),
      LeaderboardEntryModel(
        userId: 'comp_5',
        userName: 'Zane Deepcurrent',
        avatarKey: 'avatar_deep_diver',
        rank: 5,
        level: 2,
        xp: 110,
        completedQuestsCount: 1,
      ),
    ];
  }

  List<LeaderboardEntryModel> _generateCompetitors() {
    return const [
      LeaderboardEntryModel(
        userId: 'comp_1',
        userName: 'Elena Shadowstride',
        avatarKey: 'avatar_mystic_sage',
        rank: 1,
        level: 6,
        xp: 3850,
        completedQuestsCount: 18,
      ),
      LeaderboardEntryModel(
        userId: 'comp_2',
        userName: 'Kai Horizon',
        avatarKey: 'avatar_sky_pilot',
        rank: 2,
        level: 5,
        xp: 2900,
        completedQuestsCount: 14,
      ),
      LeaderboardEntryModel(
        userId: 'comp_3',
        userName: 'Marcus Storm',
        avatarKey: 'avatar_fire_trail',
        rank: 3,
        level: 4,
        xp: 2100,
        completedQuestsCount: 11,
      ),
      LeaderboardEntryModel(
        userId: 'comp_4',
        userName: 'Aria Silverleaf',
        avatarKey: 'avatar_ranger',
        rank: 4,
        level: 3,
        xp: 1400,
        completedQuestsCount: 7,
      ),
      LeaderboardEntryModel(
        userId: 'comp_5',
        userName: 'Zane Deepcurrent',
        avatarKey: 'avatar_deep_diver',
        rank: 5,
        level: 2,
        xp: 850,
        completedQuestsCount: 4,
      ),
    ];
  }
}
