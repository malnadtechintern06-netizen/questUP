import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/mysql_database_service.dart';
import '../models/quest_model.dart';

abstract class IQuestMySqlDataSource {
  Future<List<QuestModel>> fetchQuestsFromMySql();
  Future<void> saveQuestToMySql(QuestModel quest);
  Future<void> markCompletedInMySql(String questId, String userId, {int xp = 0, int coins = 0});
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
        'SELECT * FROM quests WHERE is_active = 1',
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

          // If extra fields are in json
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
        INSERT INTO quests (id, title, description, category, verification_type, latitude, longitude, radius_meters, xp_reward, coins_reward, location_name, difficulty, is_active)
        VALUES (:id, :title, :description, :category, :verification_type, :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward, :location_name, :difficulty, 1)
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
          'difficulty': quest.difficulty.name,
        },
      );
    } catch (e) {
      debugPrint('[MySQL] saveQuest error: $e');
    }
  }

  @override
  Future<void> markCompletedInMySql(String questId, String userId, {int xp = 0, int coins = 0}) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return;

    try {
      await _dbService.execute(
        '''
        INSERT INTO quest_completions (id, quest_id, user_id, xp_earned, coins_earned, completed_at)
        VALUES (:id, :quest_id, :user_id, :xp_earned, :coins_earned, NOW())
        ''',
        {
          'id': const Uuid().v4(),
          'quest_id': questId,
          'user_id': userId,
          'xp_earned': xp.toString(),
          'coins_earned': coins.toString(),
        },
      );
    } catch (e) {
      debugPrint('[MySQL] markCompleted error: $e');
    }
  }
}
