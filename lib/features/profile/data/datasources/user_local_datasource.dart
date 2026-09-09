import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/user_profile_model.dart';

abstract class IUserLocalDataSource {
  Future<UserProfileModel> getUserProfile([String? targetUserId]);
  Future<void> saveUserProfile(UserProfileModel profile);
}

class UserLocalDataSource implements IUserLocalDataSource {
  final ILocalStorageService _storage;

  UserLocalDataSource(this._storage);

  String _getUserProfileKey(String userId) => 'questup_user_profile_${userId}_v1';

  @override
  Future<UserProfileModel> getUserProfile([String? targetUserId]) async {
    // Check active logged-in user session
    final authSession = await _storage.getJson(AppConstants.keyAuthSession);
    String? sessionEmail;
    String? sessionName;
    String? sessionId;
    String? sessionPlayerId;
    if (authSession != null && authSession is Map<String, dynamic>) {
      sessionEmail = authSession['email']?.toString();
      sessionName = authSession['displayName']?.toString() ?? authSession['name']?.toString();
      sessionId = authSession['id']?.toString();
      sessionPlayerId = authSession['player_id']?.toString() ?? authSession['playerId']?.toString();
    }

    final effectiveUserId = targetUserId ?? sessionId ?? 'guest_player';
    final userSpecificKey = _getUserProfileKey(effectiveUserId);

    // 1. Try to get user-specific saved profile
    final json = await _storage.getJson(userSpecificKey);
    if (json != null && json is Map<String, dynamic>) {
      var model = UserProfileModel.fromJson(json);
      bool needsSave = false;
      if (sessionName != null && sessionName.isNotEmpty && model.name != sessionName) {
        model = UserProfileModel.fromEntity(model.copyWith(name: sessionName));
        needsSave = true;
      }
      if (model.playerId == 'QST-0000') {
        final resolvedTag = (sessionPlayerId != null && sessionPlayerId.isNotEmpty)
            ? sessionPlayerId
            : _computePlayerTag(effectiveUserId, sessionEmail);
        model = UserProfileModel.fromEntity(model.copyWith(playerId: resolvedTag));
        needsSave = true;
      }
      if (needsSave) {
        await saveUserProfile(model);
      }
      return model;
    }

    // If no active session and guest key is empty, check fallback keyUserProfile
    if (sessionId == null && targetUserId == null) {
      final fallbackJson = await _storage.getJson(AppConstants.keyUserProfile);
      if (fallbackJson != null && fallbackJson is Map<String, dynamic>) {
        return UserProfileModel.fromJson(fallbackJson);
      }
    }

    final initialPlayerId = (sessionPlayerId != null && sessionPlayerId.isNotEmpty)
        ? sessionPlayerId
        : _computePlayerTag(effectiveUserId, sessionEmail);

    // 2. Brand new clean profile for this user
    final defaultProfile = UserProfileModel(
      id: effectiveUserId,
      playerId: initialPlayerId,
      name: (sessionName != null && sessionName.isNotEmpty) ? sessionName : 'Explorer',
      email: (sessionEmail != null && sessionEmail.isNotEmpty) ? sessionEmail : 'explorer@questup.com',
      avatarKey: 'avatar_ranger',
      level: 1,
      currentXp: 0,
      xpToNextLevel: AppConstants.baseLevelXp,
      coins: 100,
      completedQuestIds: const [],
      earnedBadgeIds: const ['badge_first_step'],
      joinedAt: DateTime.now(),
    );

    await saveUserProfile(defaultProfile);
    return defaultProfile;
  }

  String _computePlayerTag(String userId, [String? email]) {
    final source = email != null && email.isNotEmpty ? email : userId;
    final bytes = utf8.encode(source);
    final hash = sha256.convert(bytes).toString();
    final numberPart = int.parse(hash.substring(0, 4), radix: 16) % 9000 + 1000;
    return 'QST-$numberPart';
  }

  @override
  Future<void> saveUserProfile(UserProfileModel profile) async {
    final key = _getUserProfileKey(profile.id);
    await _storage.saveJson(key, profile.toJson());
    await _storage.saveJson(AppConstants.keyUserProfile, profile.toJson());
  }
}
