import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/config/app_constants.dart';
import '../../../../app/config/mysql_config.dart';
import '../../../../core/services/mysql_database_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../profile/data/models/user_profile_model.dart';
import '../../../quests/data/datasources/quest_local_datasource.dart';
import '../../../quests/data/models/quest_model.dart';
import '../../../verification/data/models/quest_completion_model.dart';

class DataSyncService {
  static final DataSyncService instance = DataSyncService();

  final ILocalStorageService _storage;
  final IMySqlDatabaseService _dbService;
  bool _isSyncing = false;

  DataSyncService({
    ILocalStorageService? storage,
    IMySqlDatabaseService? dbService,
  })  : _storage = storage ?? LocalStorageService(),
        _dbService = dbService ?? MySqlDatabaseService.instance;

  /// Trigger full background migration & synchronization of local phone data to MySQL
  Future<void> synchronizeLocalDataToMySql() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('[DataSync] Starting synchronization check with MySQL...');

      // 1. Sync local users to Cloud MySQL via REST API
      await _syncLocalUsersViaRestApi();

      final isConnected = await _dbService.connect();
      if (!isConnected) {
        debugPrint('[DataSync] Direct MySQL socket not reachable currently. REST sync completed.');
        _isSyncing = false;
        return;
      }

      // 2. Synchronize Default Quests Catalog into MySQL if empty
      await _syncQuestsCatalog();

      // 3. Synchronize Local Users into MySQL
      await _syncLocalUsers();

      // 4. Synchronize Active User Profile into MySQL
      await _syncUserProfile();

      // 5. Migrate Historical Completed Quests to MySQL
      await _syncCompletedQuests();

      debugPrint('[DataSync] Full synchronization with MySQL questup_db completed successfully!');
    } catch (e) {
      debugPrint('[DataSync] Synchronization error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncLocalUsersViaRestApi() async {
    if (kIsWeb) return;

    try {
      final raw = await _storage.getJson(AppConstants.keyLocalUsers);
      if (raw is! Map<String, dynamic> || raw.isEmpty) return;

      final usersList = <Map<String, dynamic>>[];
      for (final entry in raw.entries) {
        final userData = entry.value;
        if (userData is Map<String, dynamic>) {
          final email = (userData['email'] as String?)?.trim().toLowerCase();
          if (email != null && email.isNotEmpty) {
            usersList.add(userData);
          }
        }
      }

      if (usersList.isEmpty) return;

      final payload = jsonEncode({'users': usersList});
      final candidateUrls = MySqlConfig.apiBaseUrls.map((b) => '$b/auth/sync.php').toList();

      for (final urlStr in candidateUrls) {
        HttpClient? client;
        try {
          final uri = Uri.parse(urlStr);
          client = HttpClient()
            ..connectionTimeout = const Duration(milliseconds: 2500)
            ..badCertificateCallback = ((cert, host, port) => true);

          final request = await client.postUrl(uri);
          request.headers.set('Content-Type', 'application/json; charset=utf-8');
          request.headers.set('Accept', 'application/json, */*');
          request.headers.set('User-Agent', 'QuestUP-App/1.0');
          request.write(payload);

          final response = await request.close().timeout(const Duration(milliseconds: 3000));
          if (response.statusCode == 200 || response.statusCode == 201) {
            debugPrint('[DataSync REST] ✅ Synced ${usersList.length} local users via REST API: $urlStr');
            break;
          }
        } catch (_) {
        } finally {
          client?.close(force: true);
        }
      }
    } catch (e) {
      debugPrint('[DataSync REST] Error during REST user sync: $e');
    }
  }

  Future<void> _syncQuestsCatalog() async {
    try {
      final res = await _dbService.execute('SELECT COUNT(*) as cnt FROM quests');
      int count = 0;
      if (res != null && res.rows.isNotEmpty) {
        count = int.tryParse(res.rows.first.assoc()['cnt'] ?? '') ?? 0;
      }

      // If quests table has fewer than 3 quests, seed the local catalog
      if (count < 3) {
        debugPrint('[DataSync] Seeding quests catalog into MySQL (currently $count quests)...');
        final localSource = QuestLocalDataSource(_storage);
        final defaultQuests = await localSource.getQuests();

        for (final q in defaultQuests) {
          final model = QuestModel.fromEntity(q);
          await _dbService.execute(
            '''
            INSERT INTO quests (
              id, title, description, category, verification_type,
              latitude, longitude, radius_meters, xp_reward, coins_reward,
              location_name, place_type, image_asset_path, difficulty, is_active, created_at
            ) VALUES (
              :id, :title, :description, :category, :verification_type,
              :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward,
              :location_name, :place_type, :image_asset_path, :difficulty, 1, NOW()
            )
            ON DUPLICATE KEY UPDATE
              title = VALUES(title),
              description = VALUES(description),
              xp_reward = VALUES(xp_reward),
              coins_reward = VALUES(coins_reward)
            ''',
            {
              'id': model.id,
              'title': model.title,
              'description': model.description,
              'category': model.category.name,
              'verification_type': model.verificationType.name,
              'latitude': model.latitude.toString(),
              'longitude': model.longitude.toString(),
              'radius_meters': model.radiusMeters.toString(),
              'xp_reward': model.xpReward.toString(),
              'coins_reward': model.coinReward.toString(),
              'location_name': model.locationName,
              'place_type': model.placeCategory ?? 'landmark',
              'image_asset_path': model.imageUrl ?? model.photoUrl ?? 'assets/images/hero_poster.jpg',
              'difficulty': model.difficulty.name,
            },
          );
        }
        debugPrint('[DataSync] Seeded ${defaultQuests.length} default quests into MySQL quests table.');
      }
    } catch (e) {
      debugPrint('[DataSync] Error syncing quest catalog: $e');
    }
  }

  Future<void> _syncLocalUsers() async {
    try {
      final raw = await _storage.getJson(AppConstants.keyLocalUsers);
      if (raw is Map<String, dynamic>) {
        for (final entry in raw.entries) {
          final userData = entry.value;
          if (userData is Map<String, dynamic>) {
            final email = (userData['email'] as String?)?.trim().toLowerCase();
            final name = (userData['name'] as String?)?.trim() ?? 'Explorer';
            final id = (userData['id'] as String?) ?? const Uuid().v4();
            final hash = (userData['password_hash'] as String?) ?? '';
            final salt = (userData['salt'] as String?) ?? '';

            if (email != null && email.isNotEmpty) {
              await _dbService.execute(
                '''
                INSERT INTO users (id, name, email, password_hash, salt, status, created_at)
                VALUES (:id, :name, :email, :password_hash, :salt, 'active', NOW())
                ON DUPLICATE KEY UPDATE
                  name = VALUES(name)
                ''',
                {
                  'id': id,
                  'name': name,
                  'email': email,
                  'password_hash': hash,
                  'salt': salt,
                },
              );
              debugPrint('[DataSync] MYSQL USER SYNC SUCCESS: $email ($id)');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DataSync] Error syncing local users: $e');
    }
  }

  Future<void> _syncUserProfile() async {
    try {
      final json = await _storage.getJson(AppConstants.keyUserProfile);
      if (json is Map<String, dynamic>) {
        final profile = UserProfileModel.fromJson(json);

        // 1. Ensure user row exists
        await _dbService.execute(
          '''
          INSERT INTO users (id, name, email, password_hash, salt, status, created_at)
          VALUES (:id, :name, :email, 'offline_migrated_hash', 'salt', 'active', NOW())
          ON DUPLICATE KEY UPDATE
            name = VALUES(name)
          ''',
          {
            'id': profile.id,
            'name': profile.name,
            'email': profile.email,
          },
        );

        // 2. Ensure user_profile row exists with latest stats
        await _dbService.execute(
          '''
          INSERT INTO user_profiles (
            user_id, name, email, avatar_key, level, current_xp,
            xp_to_next_level, coins, joined_at
          ) VALUES (
            :user_id, :name, :email, :avatar_key, :level, :current_xp,
            :xp_to_next_level, :coins, :joined_at
          )
          ON DUPLICATE KEY UPDATE
            level = GREATEST(level, VALUES(level)),
            current_xp = GREATEST(current_xp, VALUES(current_xp)),
            coins = GREATEST(coins, VALUES(coins)),
            name = VALUES(name)
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
        debugPrint('[DataSync] Synchronized profile to MySQL: ${profile.name} (Lvl ${profile.level}, ${profile.currentXp} XP, ${profile.coins} Coins)');

        // 3. Synchronize badges
        for (final badgeId in profile.earnedBadgeIds) {
          await _dbService.execute(
            '''
            INSERT INTO user_badges (id, user_id, badge_id, earned_at)
            VALUES (UUID(), :user_id, :badge_id, NOW())
            ON DUPLICATE KEY UPDATE earned_at = NOW()
            ''',
            {
              'user_id': profile.id,
              'badge_id': badgeId,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[DataSync] Error syncing profile: $e');
    }
  }

  Future<void> _syncCompletedQuests() async {
    try {
      final raw = await _storage.getJson(AppConstants.keyCompletions);
      if (raw is List) {
        int migratedCount = 0;
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            final comp = QuestCompletionModel.fromJson(item);

            // Duplicate check in MySQL
            final check = await _dbService.execute(
              'SELECT id FROM quest_completions WHERE quest_id = :quest_id AND user_id = :user_id LIMIT 1',
              {
                'quest_id': comp.questId,
                'user_id': comp.userId,
              },
            );

            if (check == null || check.rows.isEmpty) {
              final proofJson = comp.photoProofPath.isNotEmpty
                  ? jsonEncode({'proof': comp.photoProofPath, 'lat': comp.userLatitude, 'lng': comp.userLongitude})
                  : null;

              await _dbService.execute(
                '''
                INSERT INTO quest_completions (
                  id, quest_id, user_id, verification_type, proof_data,
                  xp_earned, coins_earned, completed_at, status
                ) VALUES (
                  :id, :quest_id, :user_id, 'locationGps', :proof_data,
                  :xp_earned, :coins_earned, :completed_at, 'verified'
                )
                ''',
                {
                  'id': comp.id.isNotEmpty ? comp.id : const Uuid().v4(),
                  'quest_id': comp.questId,
                  'user_id': comp.userId,
                  'proof_data': proofJson,
                  'xp_earned': comp.xpEarned.toString(),
                  'coins_earned': comp.coinsEarned.toString(),
                  'completed_at': comp.completedAt.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
                },
              );
              migratedCount++;
              debugPrint('[DataSync] MYSQL HISTORICAL COMPLETION MIGRATED: questId=${comp.questId}, userId=${comp.userId}');
            }
          }
        }
        if (migratedCount > 0) {
          debugPrint('[DataSync] Successfully migrated $migratedCount historical completed quests to MySQL!');
        }
      }
    } catch (e) {
      debugPrint('[DataSync] Error syncing completed quests: $e');
    }
  }
}
