import 'package:flutter/foundation.dart';
import '../../../../core/services/mysql_database_service.dart';
import '../models/user_profile_model.dart';

abstract class IUserMySqlDataSource {
  Future<UserProfileModel?> fetchProfileFromMySql(String userId);
  Future<void> saveProfileToMySql(UserProfileModel profile);
  Future<void> updateXpAndCoinsInMySql({
    required String userId,
    required int level,
    required int currentXp,
    required int xpToNextLevel,
    required int coins,
  });
  Future<void> saveUserBadgeInMySql(String userId, String badgeId);
}

class UserMySqlDataSource implements IUserMySqlDataSource {
  final IMySqlDatabaseService _dbService;

  UserMySqlDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  @override
  Future<UserProfileModel?> fetchProfileFromMySql(String userId) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return null;

    try {
      final result = await _dbService.execute(
        '''
        SELECT up.*, u.player_id
        FROM user_profiles up
        LEFT JOIN users u ON u.id = up.user_id
        WHERE up.user_id = :user_id LIMIT 1
        ''',
        {'user_id': userId},
      );

      if (result != null && result.rows.isNotEmpty) {
        final row = result.rows.first.assoc();
        final model = UserProfileModel(
          id: row['user_id'] ?? userId,
          playerId: row['player_id'] ?? 'QST-0000',
          name: row['name'] ?? 'Explorer',
          email: row['email'] ?? 'explorer@questup.com',
          avatarKey: row['avatar_key'] ?? 'avatar_ranger',
          level: int.tryParse(row['level'] ?? '') ?? 1,
          currentXp: int.tryParse(row['current_xp'] ?? '') ?? 0,
          xpToNextLevel: int.tryParse(row['xp_to_next_level'] ?? '') ?? 500,
          coins: int.tryParse(row['coins'] ?? '') ?? 100,
          completedQuestIds: const [],
          earnedBadgeIds: const [],
          joinedAt: row['joined_at'] != null
              ? (DateTime.tryParse(row['joined_at']!) ?? DateTime.now())
              : DateTime.now(),
        );
        debugPrint('[MySQL] Fetched user profile from MySQL: ${model.name} (${model.playerId}, Lvl ${model.level})');
        return model;
      }
    } catch (e) {
      debugPrint('[MySQL] Error fetching profile from MySQL: $e');
    }
    return null;
  }

  @override
  Future<void> saveProfileToMySql(UserProfileModel profile) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return;

    try {
      await _dbService.execute(
        '''
        INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, xp_to_next_level, coins, joined_at)
        VALUES (:user_id, :name, :email, :avatar_key, :level, :current_xp, :xp_to_next_level, :coins, :joined_at)
        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          email = VALUES(email),
          avatar_key = VALUES(avatar_key),
          level = VALUES(level),
          current_xp = VALUES(current_xp),
          xp_to_next_level = VALUES(xp_to_next_level),
          coins = VALUES(coins)
        ''',
        {
          'user_id': profile.id,
          'name': profile.name,
          'email': profile.email,
          'avatar_key': profile.avatarKey,
          'level': profile.level.toString(),
          'current_xp': profile.currentXp.toString(),
          'xp_to_next_level': profile.xpToNextLevel.toString(),
          'coins': profile.coins.toString(),
          'joined_at': profile.joinedAt.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
        },
      );
      debugPrint('[MySQL] MYSQL USER PROFILE INSERT/UPDATE SUCCESS: ${profile.name} (${profile.id})');
    } catch (e) {
      debugPrint('[MySQL] MYSQL USER PROFILE UPDATE FAILED: $e');
    }
  }

  @override
  Future<void> updateXpAndCoinsInMySql({
    required String userId,
    required int level,
    required int currentXp,
    required int xpToNextLevel,
    required int coins,
  }) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return;

    try {
      await _dbService.execute(
        '''
        UPDATE user_profiles
        SET level = :level,
            current_xp = :current_xp,
            xp_to_next_level = :xp_to_next_level,
            coins = :coins
        WHERE user_id = :user_id
        ''',
        {
          'level': level.toString(),
          'current_xp': currentXp.toString(),
          'xp_to_next_level': xpToNextLevel.toString(),
          'coins': coins.toString(),
          'user_id': userId,
        },
      );
      debugPrint('[MySQL] MYSQL XP/COINS UPDATE SUCCESS: userId=$userId, Level=$level, XP=$currentXp, Coins=$coins');
    } catch (e) {
      debugPrint('[MySQL] MYSQL XP/COINS UPDATE FAILED: $e');
    }
  }

  @override
  Future<void> saveUserBadgeInMySql(String userId, String badgeId) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return;

    try {
      await _dbService.execute(
        '''
        INSERT INTO user_badges (id, user_id, badge_id, earned_at)
        VALUES (UUID(), :user_id, :badge_id, NOW())
        ON DUPLICATE KEY UPDATE earned_at = NOW()
        ''',
        {
          'user_id': userId,
          'badge_id': badgeId,
        },
      );
      debugPrint('[MySQL] MYSQL USER BADGE INSERT SUCCESS: userId=$userId, badgeId=$badgeId');
    } catch (e) {
      debugPrint('[MySQL] MYSQL USER BADGE INSERT FAILED: $e');
    }
  }
}
