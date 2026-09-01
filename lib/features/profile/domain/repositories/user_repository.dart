import '../entities/user_profile.dart';

abstract class UserRepository {
  Future<UserProfile> getUserProfile();
  Future<void> saveUserProfile(UserProfile profile);
  Future<UserProfile> addXpAndCoins({
    required int xp,
    required int coins,
    required String completedQuestId,
  });
  Future<UserProfile> unlockBadge(String badgeId);
}
