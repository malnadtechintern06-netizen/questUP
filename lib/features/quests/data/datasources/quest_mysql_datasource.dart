import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/mysql_database_service.dart';
import '../../../verification/domain/entities/quest_completion.dart';
import '../models/quest_model.dart';

abstract class IQuestMySqlDataSource {
  Future<List<QuestModel>> fetchQuestsFromMySql();
  Future<void> saveQuestToMySql(QuestModel quest);
  Future<bool> saveCompletionToMySql(QuestCompletion completion);
  Future<bool> isQuestCompletedByUserInMySql(String questId, String userId);
}

class QuestMySqlDataSource implements IQuestMySqlDataSource {
  final IMySqlDatabaseService _dbService;

  QuestMySqlDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  @override
  Future<List<QuestModel>> fetchQuestsFromMySql() async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return [];

    try {
      final result = await _dbService.execute(
        'SELECT * FROM quests WHERE is_active = 1 ORDER BY created_at DESC',
      );

      if (result == null || result.rows.isEmpty) {
        return [];
      }

      final quests = <QuestModel>[];
      for (final row in result.rows) {
        try {
          final map = row.assoc();
          final questMap = <String, dynamic>{
            'id': map['id'] ?? const Uuid().v4(),
            'title': map['title'] ?? 'Landmark Quest',
            'description': map['description'] ?? 'Discover this location.',
            'category': map['category'] ?? 'location',
            'verificationType': map['verification_type'] ?? 'locationGps',
            'latitude': double.tryParse(map['latitude'] ?? '') ?? 0.0,
            'longitude': double.tryParse(map['longitude'] ?? '') ?? 0.0,
            'radiusMeters': double.tryParse(map['radius_meters'] ?? '') ?? 150.0,
            'xpReward': int.tryParse(map['xp_reward'] ?? '') ?? 100,
            'coinReward': int.tryParse(map['coins_reward'] ?? '') ?? 50,
            'locationName': map['location_name'] ?? 'Waypoint',
            'difficulty': map['difficulty'] ?? 'medium',
            'isActive': (map['is_active'] == '1' || map['is_active'] == 'true'),
          };

          if (map['image_asset_path'] != null && map['image_asset_path']!.isNotEmpty) {
            questMap['photoUrl'] = map['image_asset_path'];
            questMap['imageUrl'] = map['image_asset_path'];
          }

          final quest = QuestModel.fromJson(questMap);
          quests.add(quest);
        } catch (e) {
          debugPrint('[MySQL] Quest row parse error: $e');
        }
      }
      debugPrint('[MySQL] Fetched ${quests.length} active quests from MySQL');
      return quests;
    } catch (e) {
      debugPrint('[MySQL] fetchQuests error: $e');
      return [];
    }
  }

  @override
  Future<void> saveQuestToMySql(QuestModel quest) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return;

    try {
      await _dbService.execute(
        '''
        INSERT INTO quests (id, title, description, category, verification_type, latitude, longitude, radius_meters, xp_reward, coins_reward, location_name, place_type, image_asset_path, difficulty, is_active, created_at)
        VALUES (:id, :title, :description, :category, :verification_type, :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward, :location_name, :place_type, :image_asset_path, :difficulty, 1, NOW())
        ON DUPLICATE KEY UPDATE
          title = VALUES(title),
          description = VALUES(description),
          xp_reward = VALUES(xp_reward),
          coins_reward = VALUES(coins_reward)
        ''',
        {
          'id': quest.id,
          'title': quest.title,
          'description': quest.description,
          'category': quest.category.name,
          'verification_type': quest.verificationType.name,
          'latitude': quest.latitude.toString(),
          'longitude': quest.longitude.toString(),
          'radius_meters': quest.radiusMeters.toString(),
          'xp_reward': quest.xpReward.toString(),
          'coins_reward': quest.coinReward.toString(),
          'location_name': quest.locationName,
          'place_type': quest.placeCategory ?? 'landmark',
          'image_asset_path': quest.imageUrl ?? quest.photoUrl ?? 'assets/images/hero_poster.jpg',
          'difficulty': quest.difficulty.name,
        },
      );
      debugPrint('[MySQL] MYSQL QUEST INSERT/UPDATE SUCCESS: ${quest.title} (${quest.id})');
    } catch (e) {
      debugPrint('[MySQL] MYSQL QUEST INSERT FAILED: $e');
    }
  }

  @override
  Future<bool> isQuestCompletedByUserInMySql(String questId, String userId) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return false;

    try {
      final result = await _dbService.execute(
        'SELECT id FROM quest_completions WHERE quest_id = :quest_id AND user_id = :user_id LIMIT 1',
        {
          'quest_id': questId,
          'user_id': userId,
        },
      );
      return result != null && result.rows.isNotEmpty;
    } catch (e) {
      debugPrint('[MySQL] Check duplicate completion error: $e');
      return false;
    }
  }

  @override
  Future<bool> saveCompletionToMySql(QuestCompletion completion) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return false;

    try {
      // 1. Duplicate check
      final alreadyExists = await isQuestCompletedByUserInMySql(completion.questId, completion.userId);
      if (alreadyExists) {
        debugPrint('[MySQL] Duplicate quest completion ignored: questId=${completion.questId}, userId=${completion.userId}');
        return true;
      }

      // 2. Insert into quest_completions
      final proofJson = completion.photoProofPath.isNotEmpty
          ? '{"proof":"${completion.photoProofPath}","lat":${completion.userLatitude},"lng":${completion.userLongitude}}'
          : null;

      final res = await _dbService.execute(
        '''
        INSERT INTO quest_completions (
          id, quest_id, user_id, verification_type, proof_data,
          xp_earned, coins_earned, completed_at, status
        ) VALUES (
          :id, :quest_id, :user_id, :verification_type, :proof_data,
          :xp_earned, :coins_earned, :completed_at, 'verified'
        )
        ''',
        {
          'id': completion.id.isNotEmpty ? completion.id : const Uuid().v4(),
          'quest_id': completion.questId,
          'user_id': completion.userId,
          'verification_type': 'locationGps',
          'proof_data': proofJson,
          'xp_earned': completion.xpEarned.toString(),
          'coins_earned': completion.coinsEarned.toString(),
          'completed_at': completion.completedAt.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
        },
      );

      if (res != null) {
        debugPrint('[MySQL] MYSQL QUEST COMPLETION INSERT SUCCESS: questId=${completion.questId}, userId=${completion.userId}, XP=+${completion.xpEarned}, Coins=+${completion.coinsEarned}');
        return true;
      } else {
        debugPrint('[MySQL] MYSQL QUEST COMPLETION INSERT FAILED: Query returned null');
        return false;
      }
    } catch (e) {
      debugPrint('[MySQL] MYSQL QUEST COMPLETION INSERT FAILED: $e');
      return false;
    }
  }
}
