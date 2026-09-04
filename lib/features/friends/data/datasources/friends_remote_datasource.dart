import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:quest_up/app/config/mysql_config.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/services/mysql_database_service.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/friends/data/models/friend_request_model.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';

abstract class IFriendsRemoteDataSource {
  Future<FriendProfileModel?> searchPlayer(String query, {String? currentUserId});
  Future<FriendRequestModel> sendFriendRequest({
    required String senderId,
    required String targetTagOrId,
  });
  Future<List<FriendRequestModel>> getIncomingRequests(String userId);
  Future<List<FriendRequestModel>> getOutgoingRequests(String userId);
  Future<List<FriendProfileModel>> getFriends(String userId);
  Future<void> respondToFriendRequest({
    required String requestId,
    required String action, // 'accept' or 'reject'
    required String currentUserId,
  });
}

class FriendsRemoteDataSource implements IFriendsRemoteDataSource {
  final IMySqlDatabaseService _dbService;

  FriendsRemoteDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  String _normalizeTag(String query) {
    final trimmed = query.trim().toUpperCase();
    final numericOnly = RegExp(r'^(?:QST[\s\-_]*)?(\d+)$', caseSensitive: false);
    final match = numericOnly.firstMatch(trimmed);
    if (match != null) {
      return 'QST-${match.group(1)}';
    }
    return trimmed;
  }

  Future<Map<String, dynamic>?> _callRestApi(
    String endpointPath, {
    String method = 'GET',
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    for (final host in MySqlConfig.candidateHosts) {
      try {
        final uri = Uri.http(
          host,
          '/questup_backend/api/$endpointPath',
          queryParams,
        );

        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 2500);

        HttpClientRequest request;
        if (method == 'POST') {
          request = await client.postUrl(uri);
          request.headers.contentType = ContentType.json;
          if (body != null) {
            request.write(jsonEncode(body));
          }
        } else {
          request = await client.getUrl(uri);
        }

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode == 200) {
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          return json;
        }
      } catch (e) {
        debugPrint('[Friends REST API] Notice: Endpoint $endpointPath on $host failed: $e');
      }
    }
    return null;
  }

  @override
  Future<FriendProfileModel?> searchPlayer(String query, {String? currentUserId}) async {
    final normalizedTag = _normalizeTag(query);
    debugPrint('[Friends] Searching player for "$query" (normalized: "$normalizedTag")...');

    // 1. Try PHP REST API first
    final restResponse = await _callRestApi(
      'friends/search.php',
      queryParams: {
        'query': query,
        ...?currentUserId != null ? {'current_user_id': currentUserId} : null,
      },
    );

    if (restResponse != null && restResponse['success'] == true) {
      if (restResponse['is_self'] == true) {
        throw const AppException('This is your own Player ID. You cannot add yourself as a friend.');
      }
      final playerData = restResponse['player'];
      if (playerData is Map<String, dynamic>) {
        debugPrint('[Friends] Player found via PHP REST API: ${playerData['display_name']} (${playerData['player_id']})');
        return _mapJsonToFriendProfile(playerData);
      }
      return null;
    }

    // 2. Direct MySQL Fallback
    final connected = await _dbService.connect();
    if (!connected) return null;

    try {
      final res = await _dbService.execute(
        '''
        SELECT
          u.id,
          u.player_id,
          u.name AS username,
          COALESCE(up.name, u.name) AS display_name,
          COALESCE(up.avatar_key, 'adventurer_default') AS avatar_url,
          COALESCE(up.level, 1) AS level,
          COALESCE(up.current_xp, 0) AS xp,
          COALESCE(up.coins, 100) AS coins,
          (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id) AS completed_quests_count,
          (SELECT COUNT(*) FROM user_badges WHERE user_id = u.id) AS badges_count
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE UPPER(u.player_id) = UPPER(:normalized_tag) OR UPPER(u.name) = UPPER(:raw_name) OR UPPER(u.email) = UPPER(:raw_email)
        LIMIT 1
        ''',
        {
          'normalized_tag': normalizedTag,
          'raw_name': query.trim(),
          'raw_email': query.trim(),
        },
      );

      if (res != null && res.rows.isNotEmpty) {
        final row = res.rows.first.assoc();
        final foundId = row['id'] ?? '';
        if (currentUserId != null && foundId == currentUserId) {
          throw const AppException('This is your own Player ID. You cannot add yourself as a friend.');
        }

        debugPrint('[Friends] Player found via direct MySQL: ${row['display_name']} (${row['player_id']})');
        return _mapRowToFriendProfile(row, normalizedTag);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      debugPrint('[Friends] MySQL direct search error: $e');
    }

    return null;
  }

  @override
  Future<FriendRequestModel> sendFriendRequest({
    required String senderId,
    required String targetTagOrId,
  }) async {
    // 1. Try PHP REST API
    final restResponse = await _callRestApi(
      'friends/send_request.php',
      method: 'POST',
      body: {
        'sender_id': senderId,
        'target_tag': targetTagOrId,
      },
    );

    if (restResponse != null) {
      if (restResponse['success'] == true) {
        final reqData = restResponse['request'] as Map<String, dynamic>? ?? {};
        return FriendRequestModel(
          id: reqData['id'] as String? ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
          senderId: senderId,
          senderName: 'Explorer',
          senderTag: reqData['sender_tag'] as String? ?? 'QST-0000',
          senderAvatarKey: 'adventurer_default',
          senderLevel: 1,
          receiverId: reqData['receiver_id'] as String? ?? targetTagOrId,
          receiverTag: reqData['receiver_tag'] as String? ?? targetTagOrId,
          status: FriendRequestStatus.pending,
          createdAt: DateTime.now(),
        );
      } else {
        throw AppException(restResponse['message'] as String? ?? 'Unable to send friend request.');
      }
    }

    // 2. Direct MySQL Fallback
    final connected = await _dbService.connect();
    if (!connected) {
      throw const AppException('Server connection failed. Please check network connection.');
    }

    final sRes = await _dbService.execute(
      'SELECT id, player_id, name FROM users WHERE id = :id LIMIT 1',
      {'id': senderId},
    );
    if (sRes == null || sRes.rows.isEmpty) {
      throw const AppException('Sender account not found in database.');
    }
    final senderRow = sRes.rows.first.assoc();
    final senderTag = senderRow['player_id'] ?? 'QST-0000';

    final normalizedTarget = _normalizeTag(targetTagOrId);
    final tRes = await _dbService.execute(
      'SELECT id, player_id, name FROM users WHERE UPPER(player_id) = UPPER(:tag) OR id = :tid OR UPPER(name) = UPPER(:tname) LIMIT 1',
      {
        'tag': normalizedTarget,
        'tid': targetTagOrId,
        'tname': targetTagOrId,
      },
    );

    if (tRes == null || tRes.rows.isEmpty) {
      throw AppException('Player "$targetTagOrId" not found in database.');
    }
    final targetRow = tRes.rows.first.assoc();
    final receiverId = targetRow['id'] ?? targetTagOrId;
    final receiverTag = targetRow['player_id'] ?? normalizedTarget;

    if (senderId == receiverId || senderTag.toUpperCase() == receiverTag.toUpperCase()) {
      throw const AppException('You cannot send a friend request to yourself.');
    }

    final requestId = 'freq_${DateTime.now().millisecondsSinceEpoch}';
    await _dbService.execute(
      '''
      INSERT INTO friend_requests (id, sender_id, receiver_id, sender_tag, receiver_tag, status, created_at)
      VALUES (:id, :s_id, :r_id, :s_tag, :r_tag, 'pending', NOW())
      ''',
      {
        'id': requestId,
        's_id': senderId,
        'r_id': receiverId,
        's_tag': senderTag,
        'r_tag': receiverTag,
      },
    );

    return FriendRequestModel(
      id: requestId,
      senderId: senderId,
      senderName: senderRow['name'] ?? 'Explorer',
      senderTag: senderTag,
      senderAvatarKey: 'adventurer_default',
      senderLevel: 1,
      receiverId: receiverId,
      receiverTag: receiverTag,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<FriendRequestModel>> getIncomingRequests(String userId) async {
    final restResp = await _callRestApi('friends/list_requests.php', queryParams: {'user_id': userId});
    if (restResp != null && restResp['success'] == true) {
      final list = restResp['incoming_requests'] as List? ?? [];
      return list.map((item) => FriendRequestModel(
        id: item['id'] as String? ?? '',
        senderId: item['sender_id'] as String? ?? '',
        senderName: item['sender_name'] as String? ?? 'Explorer',
        senderTag: item['sender_tag'] as String? ?? 'QST-0000',
        senderAvatarKey: item['sender_avatar_key'] as String? ?? 'adventurer_default',
        senderLevel: int.tryParse(item['sender_level'].toString()) ?? 1,
        receiverId: item['receiver_id'] as String? ?? userId,
        receiverTag: item['receiver_tag'] as String? ?? 'QST-0000',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now(),
      )).toList();
    }
    return [];
  }

  @override
  Future<List<FriendRequestModel>> getOutgoingRequests(String userId) async {
    final restResp = await _callRestApi('friends/list_requests.php', queryParams: {'user_id': userId});
    if (restResp != null && restResp['success'] == true) {
      final list = restResp['outgoing_requests'] as List? ?? [];
      return list.map((item) => FriendRequestModel(
        id: item['id'] as String? ?? '',
        senderId: item['sender_id'] as String? ?? userId,
        senderName: 'You',
        senderTag: item['sender_tag'] as String? ?? 'QST-0000',
        senderAvatarKey: 'adventurer_default',
        senderLevel: 1,
        receiverId: item['receiver_id'] as String? ?? '',
        receiverTag: item['receiver_tag'] as String? ?? 'QST-0000',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now(),
      )).toList();
    }
    return [];
  }

  @override
  Future<List<FriendProfileModel>> getFriends(String userId) async {
    final restResp = await _callRestApi('friends/list_requests.php', queryParams: {'user_id': userId});
    if (restResp != null && restResp['success'] == true) {
      final list = restResp['friends'] as List? ?? [];
      return list.map((item) => _mapJsonToFriendProfile(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<void> respondToFriendRequest({
    required String requestId,
    required String action,
    required String currentUserId,
  }) async {
    await _callRestApi(
      'friends/respond_request.php',
      method: 'POST',
      body: {
        'request_id': requestId,
        'action': action,
        'user_id': currentUserId,
      },
    );
  }

  FriendProfileModel _mapJsonToFriendProfile(Map<String, dynamic> json) {
    return FriendProfileModel(
      userId: json['id'] as String? ?? json['user_id'] as String? ?? '',
      playerTag: json['player_id'] as String? ?? json['player_tag'] as String? ?? 'QST-0000',
      name: json['display_name'] as String? ?? json['name'] as String? ?? json['username'] as String? ?? 'Explorer',
      avatarKey: json['avatar_url'] as String? ?? json['avatar_key'] as String? ?? 'avatar_ranger',
      level: int.tryParse(json['level'].toString()) ?? 1,
      currentXp: int.tryParse(json['xp'].toString()) ?? int.tryParse(json['current_xp'].toString()) ?? 0,
      coins: int.tryParse(json['coins'].toString()) ?? 100,
      rank: 1,
      rankTitle: 'Pathfinder',
      completedQuestsCount: int.tryParse(json['completed_quests_count'].toString()) ?? 0,
      gamesPlayedCount: (int.tryParse(json['completed_quests_count'].toString()) ?? 0) + 1,
      completedQuests: const [],
      earnedBadges: const [],
      friendshipDate: DateTime.now(),
      isOnline: true,
      lastActiveText: 'Active on Radar',
    );
  }

  FriendProfileModel _mapRowToFriendProfile(Map<String, String?> row, String fallbackTag) {
    return FriendProfileModel(
      userId: row['id'] ?? '',
      playerTag: row['player_id'] ?? fallbackTag,
      name: row['display_name'] ?? row['username'] ?? 'Explorer',
      avatarKey: row['avatar_url'] ?? 'avatar_ranger',
      level: int.tryParse(row['level'] ?? '1') ?? 1,
      currentXp: int.tryParse(row['xp'] ?? '0') ?? 0,
      coins: int.tryParse(row['coins'] ?? '100') ?? 100,
      rank: 1,
      rankTitle: 'Pathfinder',
      completedQuestsCount: int.tryParse(row['completed_quests_count'] ?? '0') ?? 0,
      gamesPlayedCount: (int.tryParse(row['completed_quests_count'] ?? '0') ?? 0) + 1,
      completedQuests: const [],
      earnedBadges: const [],
      friendshipDate: DateTime.now(),
      isOnline: true,
      lastActiveText: 'Active on Radar',
    );
  }
}
