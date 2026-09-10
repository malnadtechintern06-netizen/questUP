import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../app/config/mysql_config.dart';
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

  Future<bool> _syncProfileViaRest(Map<String, dynamic> data) async {
    final payload = jsonEncode(data);
    for (final base in MySqlConfig.apiBaseUrls) {
      final urlStr = '$base/profile/update.php';
      HttpClient? client;
      try {
        final uri = Uri.parse(urlStr);
        client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 2500)
          ..badCertificateCallback = ((cert, host, port) => true);

        final req = await client.postUrl(uri);
        req.headers.set('Content-Type', 'application/json; charset=utf-8');
        req.headers.set('Accept', 'application/json');
        req.write(payload);

        final res = await req.close().timeout(const Duration(milliseconds: 3000));
        if (res.statusCode == 200 || res.statusCode == 201) {
          MySqlConfig.workingApiBaseUrl = base;
          debugPrint('[Profile REST] Profile synced to MySQL via $urlStr');
          return true;
        }
      } catch (_) {
      } finally {
        client?.close(force: true);
      }
    }
    return false;
  }

  @override
  Future<UserProfileModel?> fetchProfileFromMySql(String userId) async {
    // 1. Try REST API
    for (final base in MySqlConfig.apiBaseUrls) {
      final urlStr = '$base/profile/get.php?user_id=${Uri.encodeComponent(userId)}';
      HttpClient? client;
      try {
        final uri = Uri.parse(urlStr);
        client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 2000)
          ..badCertificateCallback = ((cert, host, port) => true);

        final req = await client.getUrl(uri);
        req.headers.set('Accept', 'application/json');

        final res = await req.close().timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final json = jsonDecode(body);
          if (json is Map && json['success'] == true && json['profile'] != null) {
            final p = json['profile'] as Map<String, dynamic>;
            return UserProfileModel(
              id: p['user_id'] ?? userId,
              playerId: p['player_id'] ?? 'QST-0000',
              name: p['name'] ?? 'Explorer',
              email: p['email'] ?? '',
              avatarKey: p['avatar_key'] ?? 'avatar_ranger',
              level: (p['level'] as num?)?.toInt() ?? 1,
              currentXp: (p['current_xp'] as num?)?.toInt() ?? 0,
              xpToNextLevel: (p['xp_to_next_level'] as num?)?.toInt() ?? 500,
              coins: (p['coins'] as num?)?.toInt() ?? 100,
              completedQuestIds: (p['completed_quest_ids'] as List?)?.cast<String>() ?? const [],
              earnedBadgeIds: (p['earned_badge_ids'] as List?)?.cast<String>() ?? const [],
              joinedAt: p['joined_at'] != null ? (DateTime.tryParse(p['joined_at']) ?? DateTime.now()) : DateTime.now(),
            );
          }
        }
      } catch (_) {
      } finally {
        client?.close(force: true);
      }
    }

    // 2. Direct MySQL fallback
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
        return model;
      }
    } catch (e) {
      debugPrint('[MySQL] Error fetching profile from MySQL: $e');
    }
    return null;
  }

  @override
  Future<void> saveProfileToMySql(UserProfileModel profile) async {
    // 1. Primary: Sync via Backend REST API
    final synced = await _syncProfileViaRest({
      'user_id': profile.id,
      'name': profile.name,
      'email': profile.email,
      'avatar_key': profile.avatarKey,
      'level': profile.level,
      'current_xp': profile.currentXp,
      'xp_to_next_level': profile.xpToNextLevel,
      'coins': profile.coins,
    });

    if (synced) {
      // Backend REST API successfully saved to MySQL - skip direct socket connection
      return;
    }

    // 2. Direct MySQL fallback (only if REST API is completely unreachable)
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
    } catch (e) {
      debugPrint('[MySQL] USER PROFILE UPDATE: $e');
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
    // 1. Primary: REST API sync
    final synced = await _syncProfileViaRest({
      'user_id': userId,
      'level': level,
      'current_xp': currentXp,
      'xp_to_next_level': xpToNextLevel,
      'coins': coins,
    });

    if (synced) {
      // Backend REST API successfully saved to MySQL - skip direct socket connection
      return;
    }

    // 2. Direct MySQL fallback (only if REST API is completely unreachable)
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
    } catch (e) {
      debugPrint('[MySQL] XP/COINS UPDATE: $e');
    }
  }

  @override
  Future<void> saveUserBadgeInMySql(String userId, String badgeId) async {
    // 1. Primary: Sync via Backend REST API
    final synced = await _syncProfileViaRest({
      'user_id': userId,
      'badge_id': badgeId,
    });

    if (synced) return;

    // 2. Direct MySQL fallback (only if REST is unreachable)
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
    } catch (e) {
      debugPrint('[MySQL] BADGE INSERT: $e');
    }
  }
}
