import '../../../../app/config/app_constants.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_local_datasource.dart';
import '../models/user_profile_model.dart';

class UserRepositoryImpl implements UserRepository {
  final IUserLocalDataSource _localDataSource;

  UserRepositoryImpl(this._localDataSource);

  @override
  Future<UserProfile> getUserProfile() async {
    return await _localDataSource.getUserProfile();
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    await _localDataSource.saveUserProfile(UserProfileModel.fromEntity(profile));
  }

  @override
  Future<UserProfile> addXpAndCoins({
    required int xp,
    required int coins,
    required String completedQuestId,
  }) async {
    final current = await _localDataSource.getUserProfile();

    int newXp = current.currentXp + xp;
    int currentLevel = current.level;
    int xpRequired = current.xpToNextLevel;

    // Level up calculation loop (handles multi-level jumps if massive XP awarded)
    while (newXp >= xpRequired) {
      newXp -= xpRequired;
      currentLevel++;
      xpRequired = (xpRequired * AppConstants.xpMultiplierPerLevel).round();
    }

    final updatedCompletedQuests = List<String>.from(current.completedQuestIds);
    if (!updatedCompletedQuests.contains(completedQuestId)) {
      updatedCompletedQuests.add(completedQuestId);
    }

    final updated = current.copyWith(
      level: currentLevel,
      currentXp: newXp,
      xpToNextLevel: xpRequired,
      coins: current.coins + coins,
      completedQuestIds: updatedCompletedQuests,
    );

    await _localDataSource.saveUserProfile(UserProfileModel.fromEntity(updated));
    return updated;
  }

  @override
  Future<UserProfile> unlockBadge(String badgeId) async {
    final current = await _localDataSource.getUserProfile();
    if (current.earnedBadgeIds.contains(badgeId)) {
      return current;
    }

    final updatedBadges = List<String>.from(current.earnedBadgeIds)..add(badgeId);
    final updated = current.copyWith(earnedBadgeIds: updatedBadges);

    await _localDataSource.saveUserProfile(UserProfileModel.fromEntity(updated));
    return updated;
  }
}
