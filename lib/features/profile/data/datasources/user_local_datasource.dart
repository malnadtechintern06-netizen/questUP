import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/user_profile_model.dart';

abstract class IUserLocalDataSource {
  Future<UserProfileModel> getUserProfile();
  Future<void> saveUserProfile(UserProfileModel profile);
}

class UserLocalDataSource implements IUserLocalDataSource {
  final ILocalStorageService _storage;

  UserLocalDataSource(this._storage);

  @override
  Future<UserProfileModel> getUserProfile() async {
    final json = await _storage.getJson(AppConstants.keyUserProfile);
    if (json != null && json is Map<String, dynamic>) {
      return UserProfileModel.fromJson(json);
    }

    // Default Initial Profile
    final defaultProfile = UserProfileModel(
      id: 'player_main',
      name: 'Alex Vanguard',
      email: 'explorer@questup.com',
      avatarKey: 'avatar_ranger',
      level: 1,
      currentXp: 150,
      xpToNextLevel: AppConstants.baseLevelXp,
      coins: 300,
      completedQuestIds: const [],
      earnedBadgeIds: const ['badge_first_step'],
      joinedAt: DateTime.now(),
    );

    await saveUserProfile(defaultProfile);
    return defaultProfile;
  }

  @override
  Future<void> saveUserProfile(UserProfileModel profile) async {
    await _storage.saveJson(AppConstants.keyUserProfile, profile.toJson());
  }
}
