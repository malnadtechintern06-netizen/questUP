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
    // Check if there is an active logged-in user session
    final authSession = await _storage.getJson(AppConstants.keyAuthSession);
    String? sessionEmail;
    String? sessionName;
    String? sessionId;
    if (authSession != null && authSession is Map<String, dynamic>) {
      sessionEmail = authSession['email']?.toString();
      sessionName = authSession['displayName']?.toString() ?? authSession['name']?.toString();
      sessionId = authSession['id']?.toString();
    }

    final json = await _storage.getJson(AppConstants.keyUserProfile);
    if (json != null && json is Map<String, dynamic>) {
      final model = UserProfileModel.fromJson(json);
      // If user is logged in, synchronize profile email & name with active session
      if (sessionEmail != null && sessionEmail.isNotEmpty && model.email != sessionEmail) {
        final updated = UserProfileModel.fromEntity(
          model.copyWith(
            id: sessionId ?? model.id,
            name: (sessionName != null && sessionName.isNotEmpty) ? sessionName : model.name,
            email: sessionEmail,
          ),
        );
        await saveUserProfile(updated);
        return updated;
      }
      return model;
    }

    // Default Initial Profile populated with logged in session if available
    final defaultProfile = UserProfileModel(
      id: sessionId ?? 'player_main',
      name: (sessionName != null && sessionName.isNotEmpty) ? sessionName : 'Explorer',
      email: (sessionEmail != null && sessionEmail.isNotEmpty) ? sessionEmail : 'explorer@questup.com',
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
