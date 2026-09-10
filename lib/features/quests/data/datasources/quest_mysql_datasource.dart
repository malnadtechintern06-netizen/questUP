import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/config/mysql_config.dart';
import '../../../../core/services/mysql_database_service.dart';
import '../../../verification/domain/entities/quest_completion.dart';
import '../models/quest_model.dart';

abstract class IQuestMySqlDataSource {
  Future<List<QuestModel>> fetchQuestsFromMySql({String? userId, double? userLat, double? userLon});
  Future<List<QuestModel>> generateLocationQuests({required double latitude, required double longitude, String? userId, int? radiusMeters});
  Future<void> saveQuestToMySql(QuestModel quest);
  Future<bool> saveCompletionToMySql(QuestCompletion completion);
  Future<bool> isQuestCompletedByUserInMySql(String questId, String userId);
  Future<bool> shareQuestWithFriend({
    required String questId,
    required String questTitle,
    required String senderId,
    required String senderName,
    required String senderTag,
    required String receiverId,
  });
  Future<List<Map<String, dynamic>>> fetchSharedQuests(String userId);
}

class QuestMySqlDataSource implements IQuestMySqlDataSource {
  final IMySqlDatabaseService _dbService;

  QuestMySqlDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  static String? _workingApiBaseUrl;
  Future<List<QuestModel>>? _inFlightFetch;

  Future<List<QuestModel>> _fetchFromRestApi({String? userId, double? userLat, double? userLon}) async {
    if (_inFlightFetch != null) {
      return await _inFlightFetch!;
    }
    final fetchFuture = _executeRestApiFetch(userId: userId, userLat: userLat, userLon: userLon);
    _inFlightFetch = fetchFuture;
    try {
      return await fetchFuture;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<List<QuestModel>> _executeRestApiFetch({String? userId, double? userLat, double? userLon}) async {
    final urlsToTry = <String>[
      if (_workingApiBaseUrl != null && _workingApiBaseUrl!.isNotEmpty) _workingApiBaseUrl!,
      ...MySqlConfig.apiBaseUrls.where((u) => u != _workingApiBaseUrl),
    ];

    for (final baseUrl in urlsToTry) {
      HttpClient? client;
      try {
        final queryParams = <String, String>{};
        if (userId != null && userId.isNotEmpty) queryParams['user_id'] = userId;
        if (userLat != null) queryParams['lat'] = userLat.toString();
        if (userLon != null) queryParams['lng'] = userLon.toString();

        final baseUri = Uri.parse('$baseUrl/quests/list.php');
        final uri = queryParams.isNotEmpty ? baseUri.replace(queryParameters: queryParams) : baseUri;

        debugPrint('[QuestUP] API URL: $baseUrl');
        debugPrint('[QuestUP] Fetching quests... from $uri');

        client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1500);
        client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

        final request = await client.getUrl(uri);
        request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) QuestUP-App');
        request.headers.set('Accept', 'application/json, text/html, */*');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('Pragma', 'no-cache');

        final response = await request.close().timeout(const Duration(milliseconds: 2500));
        debugPrint('[QuestUP] HTTP status: ${response.statusCode} from $baseUrl');

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final list = _parseQuestsFromJson(responseBody);
          if (list != null) {
            _workingApiBaseUrl = baseUrl;
            MySqlConfig.workingApiBaseUrl = baseUrl;
            debugPrint('[QuestUP] API quest count: ${list.length}');
            if (list.isNotEmpty) {
              debugPrint('[QuestUP] First quest ID: ${list.first.id} ("${list.first.title}")');
            }
            return list;
          }
        }
      } catch (e) {
        debugPrint('[QuestUP] Request failed on $baseUrl: $e');
      } finally {
        try {
          client?.close();
        } catch (_) {}
      }
    }
    return [];
  }

  @override
  Future<List<QuestModel>> generateLocationQuests({
    required double latitude,
    required double longitude,
    String? userId,
    int? radiusMeters,
  }) async {
    debugPrint('[QuestUP GPS] Current latitude: $latitude');
    debugPrint('[QuestUP GPS] Current longitude: $longitude');
    debugPrint('[QuestUP Location Quest] Requesting nearby landmarks...');

    final urlsToTry = <String>[
      if (_workingApiBaseUrl != null && _workingApiBaseUrl!.isNotEmpty) _workingApiBaseUrl!,
      ...MySqlConfig.apiBaseUrls.where((u) => u != _workingApiBaseUrl),
    ];

    for (final baseUrl in urlsToTry) {
      HttpClient? client;
      try {
        final uri = Uri.parse('$baseUrl/quests/generate_location_quests.php');
        client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 3000);
        client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('User-Agent', 'QuestUP-App');

        final payload = jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          'radius_meters': ?radiusMeters,
        });
        request.write(payload);

        final response = await request.close().timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final list = _parseQuestsFromJson(responseBody);
          if (list != null && list.isNotEmpty) {
            _workingApiBaseUrl = baseUrl;
            MySqlConfig.workingApiBaseUrl = baseUrl;
            debugPrint('[QuestUP Location Quest] Places found: ${list.length}');
            debugPrint('[QuestUP Location Quest] Generating quests: ${list.length}');
            debugPrint('[QuestUP Location Quest] Generated quest count: ${list.length}');
            return list;
          }
        }
      } catch (e) {
        debugPrint('[QuestUP Location Quest] Generation request failed on $baseUrl: $e');
      } finally {
        try {
          client?.close();
        } catch (_) {}
      }
    }
    return [];
  }

  List<QuestModel>? _parseQuestsFromJson(String rawJson) {
    try {
      final trimmed = rawJson.trim();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        return null;
      }
      final data = jsonDecode(trimmed);
      if (data is Map && data['success'] == true && data['quests'] is List) {
        final list = <QuestModel>[];
        for (final item in data['quests']) {
          try {
            final q = QuestModel.fromJson(Map<String, dynamic>.from(item));
            if (q.isActive) {
              list.add(q);
            }
          } catch (_) {}
        }
        return list;
      }
    } catch (e) {
      debugPrint('[QuestUP] JSON parse error: $e');
    }
    return null;
  }

  @override
  Future<List<QuestModel>> fetchQuestsFromMySql({String? userId, double? userLat, double? userLon}) async {
    // 1. Try Local REST API first (from local XAMPP / MySQL)
    final restQuests = await _fetchFromRestApi(userId: userId, userLat: userLat, userLon: userLon);
    if (restQuests.isNotEmpty) {
      return restQuests;
    }

    // 2. Fallback to direct MySQL TCP (for local / LAN setups)
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
            'sourceType': map['source_type'] ?? 'admin',
            'googlePlaceId': map['google_place_id'],
            'generationLatitude': double.tryParse(map['generation_latitude'] ?? ''),
            'generationLongitude': double.tryParse(map['generation_longitude'] ?? ''),
            'userId': map['user_id'],
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
        INSERT INTO quests (
          id, title, description, category, verification_type,
          latitude, longitude, radius_meters, xp_reward, coins_reward,
          location_name, place_type, image_asset_path, difficulty,
          source_type, google_place_id, generation_latitude, generation_longitude, user_id,
          is_active, created_at
        )
        VALUES (
          :id, :title, :description, :category, :verification_type,
          :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward,
          :location_name, :place_type, :image_asset_path, :difficulty,
          :source_type, :google_place_id, :generation_latitude, :generation_longitude, :user_id,
          1, NOW()
        )
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
          'source_type': quest.sourceType,
          'google_place_id': quest.googlePlaceId ?? '',
          'generation_latitude': quest.generationLatitude?.toString() ?? '',
          'generation_longitude': quest.generationLongitude?.toString() ?? '',
          'user_id': quest.userId ?? '',
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

  @override
  Future<bool> shareQuestWithFriend({
    required String questId,
    required String questTitle,
    required String senderId,
    required String senderName,
    required String senderTag,
    required String receiverId,
  }) async {
    final urlsToTry = <String>[
      if (_workingApiBaseUrl != null && _workingApiBaseUrl!.isNotEmpty) _workingApiBaseUrl!,
      ...MySqlConfig.apiBaseUrls.where((u) => u != _workingApiBaseUrl),
    ];

    final body = {
      'quest_id': questId,
      'quest_title': questTitle,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_tag': senderTag,
      'receiver_id': receiverId,
    };

    for (final baseUrl in urlsToTry) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1500);
        client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
        final uri = Uri.parse('$baseUrl/quests/share.php');
        final req = await client.postUrl(uri);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
        final resp = await req.close();
        final respBody = await resp.transform(utf8.decoder).join();
        client.close();
        final json = jsonDecode(respBody) as Map<String, dynamic>;
        if (json['success'] == true) {
          _workingApiBaseUrl = baseUrl;
          return true;
        }
      } catch (e) {
        debugPrint('[QuestUP Share] Error on $baseUrl: $e');
      }
    }
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSharedQuests(String userId) async {
    final urlsToTry = <String>[
      if (_workingApiBaseUrl != null && _workingApiBaseUrl!.isNotEmpty) _workingApiBaseUrl!,
      ...MySqlConfig.apiBaseUrls.where((u) => u != _workingApiBaseUrl),
    ];

    for (final baseUrl in urlsToTry) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1500);
        client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
        final uri = Uri.parse('$baseUrl/quests/get_shared.php?user_id=$userId');
        final req = await client.getUrl(uri);
        final resp = await req.close();
        final respBody = await resp.transform(utf8.decoder).join();
        client.close();
        final json = jsonDecode(respBody) as Map<String, dynamic>;
        if (json['success'] == true) {
          _workingApiBaseUrl = baseUrl;
          final incoming = json['incoming_shared'] as List? ?? [];
          return incoming.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (e) {
        debugPrint('[QuestUP Get Shared] Error on $baseUrl: $e');
      }
    }
    return [];
  }
}
