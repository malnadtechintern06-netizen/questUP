import '../../../../app/config/app_constants.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_local_datasource.dart';
import '../datasources/user_mysql_datasource.dart';
import '../models/user_profile_model.dart';

class UserRepositoryImpl implements UserRepository {
  final IUserLocalDataSource _localDataSource;
  final IUserMySqlDataSource _mySqlDataSource;

  UserRepositoryImpl(
    this._localDataSource, [
    IUserMySqlDataSource? mySqlDataSource,
  ]) : _mySqlDataSource = mySqlDataSource ?? UserMySqlDataSource();

  @override
  Future<UserProfile> getUserProfile() async {
    final localProfile = await _localDataSource.getUserProfile();

    // Check remote MySQL profile asynchronously in background without delaying instant UI render
    _syncRemoteProfile(localProfile);

    return localProfile;
  }

  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  void _syncRemoteProfile(UserProfile localProfile) {
    if (_isSyncing) return;
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!).inSeconds < 30) {
      return;
    }
    _isSyncing = true;
    _lastSyncTime = now;

    Future(() async {
      try {
        final remoteProfile = await _mySqlDataSource.fetchProfileFromMySql(localProfile.id);
        if (remoteProfile != null) {
          if (remoteProfile.currentXp > localProfile.currentXp || remoteProfile.level > localProfile.level) {
            final merged = localProfile.copyWith(
              level: remoteProfile.level,
              currentXp: remoteProfile.currentXp,
              xpToNextLevel: remoteProfile.xpToNextLevel,
              coins: remoteProfile.coins,
            );
            await _localDataSource.saveUserProfile(UserProfileModel.fromEntity(merged));
          } else if (localProfile.currentXp > remoteProfile.currentXp || localProfile.level > remoteProfile.level) {
            await _mySqlDataSource.saveProfileToMySql(UserProfileModel.fromEntity(localProfile));
          }
        } else {
          await _mySqlDataSource.saveProfileToMySql(UserProfileModel.fromEntity(localProfile));
        }
      } catch (_) {
      } finally {
        _isSyncing = false;
      }
    });
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    await _localDataSource.saveUserProfile(model);
    try {
      await _mySqlDataSource.saveProfileToMySql(model);
    } catch (_) {}
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

    final model = UserProfileModel.fromEntity(updated);
    await _localDataSource.saveUserProfile(model);

    // Synchronize to MySQL database
    try {
      await _mySqlDataSource.updateXpAndCoinsInMySql(
        userId: updated.id,
        level: currentLevel,
        currentXp: newXp,
        xpToNextLevel: xpRequired,
        coins: updated.coins,
      );
    } catch (_) {}

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

    try {
      await _mySqlDataSource.saveUserBadgeInMySql(updated.id, badgeId);
    } catch (_) {}

    return updated;
  }
}
