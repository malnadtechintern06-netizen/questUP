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
    String? senderTag,
    String? senderName,
    String? senderEmail,
  });
  Future<List<FriendRequestModel>> getIncomingRequests(String userId);
  Future<List<FriendRequestModel>> getOutgoingRequests(String userId);
  Future<List<FriendProfileModel>> getFriends(String userId);
  Future<void> respondToFriendRequest({
    required String requestId,
    required String action, // 'accept' or 'reject'
    required String currentUserId,
  });
  Future<List<FriendCompletedQuestSummaryModel>> getFriendHistory({
    required String currentUserId,
    required String targetPlayerIdOrUserId,
  });
  Future<void> removeFriend({
    required String currentUserId,
    required String friendUserId,
  });
  Future<List<FriendProfileModel>> getSuggestedPlayers({
    required String currentUserId,
  });
}

class FriendsRemoteDataSource implements IFriendsRemoteDataSource {
  final IMySqlDatabaseService _dbService;

  FriendsRemoteDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  String _normalizeTag(String query) {
    var trimmed = query.trim().toUpperCase();
    if (trimmed.startsWith('#')) {
      trimmed = trimmed.substring(1).trim();
    }
    final numericOnly = RegExp(r'^(?:QST[\s\-_]*)?(\d+)$', caseSensitive: false);
    final match = numericOnly.firstMatch(trimmed);
    if (match != null) {
      return 'QST-${match.group(1)}';
    }
    return trimmed;
  }

  static String? _workingApiBaseUrl;

  Future<Map<String, dynamic>?> _callRestApi(
    String endpointPath, {
    String method = 'GET',
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    final candidateUrls = <String>[
      if (_workingApiBaseUrl != null && _workingApiBaseUrl!.isNotEmpty) _workingApiBaseUrl!,
      ...MySqlConfig.apiBaseUrls.where((u) => u != _workingApiBaseUrl),
    ];

    for (final base in candidateUrls) {
      try {
        final baseUri = Uri.parse('$base/$endpointPath');
        final uri = (queryParams != null && queryParams.isNotEmpty)
            ? baseUri.replace(queryParameters: queryParams)
            : baseUri;

        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1200);
        client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

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

        if (response.statusCode >= 200 && response.statusCode < 500) {
          _workingApiBaseUrl = base;
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          json['_status_code'] = response.statusCode;
          return json;
        }
      } catch (e) {
        debugPrint('[Friends REST API] Notice: Endpoint $endpointPath on $base failed: $e');
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
        final matchedId = row['id'];
        if (currentUserId != null && matchedId == currentUserId) {
          throw const AppException('This is your own Player ID. You cannot add yourself as a friend.');
        }
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
    String? senderTag,
    String? senderName,
    String? senderEmail,
  }) async {
    // 1. Try PHP REST API
    final restResponse = await _callRestApi(
      'friends/send_request.php',
      method: 'POST',
      body: {
        'sender_id': senderId,
        'target_tag': targetTagOrId,
        if (senderTag != null && senderTag.isNotEmpty) 'sender_tag': senderTag,
        if (senderName != null && senderName.isNotEmpty) 'sender_name': senderName,
        if (senderEmail != null && senderEmail.isNotEmpty) 'sender_email': senderEmail,
      },
    );

    if (restResponse != null) {
      if (restResponse['success'] == true) {
        final reqData = restResponse['request'] as Map<String, dynamic>? ?? {};
        return FriendRequestModel(
          id: reqData['id'] as String? ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
          senderId: senderId,
          senderName: senderName ?? 'Explorer',
          senderTag: reqData['sender_tag'] as String? ?? senderTag ?? 'QST-0000',
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
    final resolvedSenderTag = senderRow['player_id'] ?? senderTag ?? 'QST-0000';

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

    if (senderId == receiverId || resolvedSenderTag.toUpperCase() == receiverTag.toUpperCase()) {
      throw const AppException('You cannot send a friend request to yourself.');
    }

    // Check existing request
    final existingRes = await _dbService.execute(
      '''
      SELECT id, status FROM friend_requests
      WHERE (sender_id = :u1 AND receiver_id = :u2) OR (sender_id = :u3 AND receiver_id = :u4)
      ORDER BY id DESC LIMIT 1
      ''',
      {'u1': senderId, 'u2': receiverId, 'u3': receiverId, 'u4': senderId},
    );

    if (existingRes != null && existingRes.rows.isNotEmpty) {
      final exRow = existingRes.rows.first.assoc();
      final exStatus = exRow['status'];
      if (exStatus == 'accepted') {
        throw const AppException('You are already friends with this player.');
      }
      if (exStatus == 'pending') {
        throw const AppException('A pending friend request already exists between you and this player.');
      }
    }

    final requestId = 'freq_${DateTime.now().millisecondsSinceEpoch}';
    await _dbService.execute(
      '''
      INSERT INTO friend_requests (id, sender_id, receiver_id, sender_tag, receiver_tag, status, created_at)
      VALUES (:id, :s_id, :r_id, :s_tag, :r_tag, 'pending', NOW())
      ON DUPLICATE KEY UPDATE status = 'pending', updated_at = NOW()
      ''',
      {
        'id': requestId,
        's_id': senderId,
        'r_id': receiverId,
        's_tag': resolvedSenderTag,
        'r_tag': receiverTag,
      },
    );

    return FriendRequestModel(
      id: requestId,
      senderId: senderId,
      senderName: senderRow['name'] ?? senderName ?? 'Explorer',
      senderTag: resolvedSenderTag,
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
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return _mapJsonToFriendProfile(map, forceFriend: true);
      }).toList();
    }

    // Direct MySQL fallback
    final connected = await _dbService.connect();
    if (!connected) return [];

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
          (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id) AS completed_quests_count
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE u.id IN (
          SELECT CASE WHEN sender_id = :u1 THEN receiver_id ELSE sender_id END
          FROM friend_requests
          WHERE (sender_id = :u2 OR receiver_id = :u3) AND status = 'accepted'
        )
        ''',
        {'u1': userId, 'u2': userId, 'u3': userId},
      );

      if (res != null) {
        return res.rows.map((row) {
          return _mapRowToFriendProfile(row.assoc(), 'QST-0000', isFriend: true, friendshipStatus: 'accepted');
        }).toList();
      }
    } catch (e) {
      debugPrint('[FriendsRemoteDataSource] Fallback getFriends error: $e');
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

  @override
  Future<List<FriendCompletedQuestSummaryModel>> getFriendHistory({
    required String currentUserId,
    required String targetPlayerIdOrUserId,
  }) async {
    // 1. Try PHP REST API with strict zero-trust privacy check
    final restResponse = await _callRestApi(
      'friends/history.php',
      queryParams: {
        'user_id': currentUserId,
        'target_player_id': targetPlayerIdOrUserId,
      },
    );

    if (restResponse != null) {
      if (restResponse['success'] == true) {
        final list = restResponse['history'] as List? ?? [];
        return list
            .map((item) => FriendCompletedQuestSummaryModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      // Access denied or not friends: strictly return empty list
      debugPrint('[FriendsRemoteDataSource] history.php access denied: ${restResponse['error']}');
      return [];
    }

    // 2. Direct MySQL Fallback: Strict privacy check
    final connected = await _dbService.connect();
    if (!connected) return [];

    try {
      final normalizedTarget = _normalizeTag(targetPlayerIdOrUserId);
      final tRes = await _dbService.execute(
        'SELECT id, player_id FROM users WHERE UPPER(player_id) = UPPER(:tag) OR id = :tid LIMIT 1',
        {'tag': normalizedTarget, 'tid': targetPlayerIdOrUserId},
      );
      if (tRes == null || tRes.rows.isEmpty) return [];
      final targetId = tRes.rows.first.assoc()['id'] ?? '';

      final isSelf = (currentUserId == targetId);
      if (!isSelf) {
        final fRes = await _dbService.execute(
          '''
          SELECT id FROM friend_requests
          WHERE ((sender_id = :u1 AND receiver_id = :t1) OR (sender_id = :t2 AND receiver_id = :u2))
            AND status = 'accepted'
          LIMIT 1
          ''',
          {'u1': currentUserId, 't1': targetId, 't2': targetId, 'u2': currentUserId},
        );

        if (fRes == null || fRes.rows.isEmpty) {
          debugPrint('[FriendsRemoteDataSource] Fallback: Access blocked. $currentUserId and $targetId are not friends.');
          return [];
        }
      }

      final qRes = await _dbService.execute(
        '''
        SELECT 
          qc.quest_id,
          qc.completed_at,
          qc.xp_earned,
          qc.coins_earned,
          q.title,
          q.category,
          COALESCE(q.location_name, 'Unknown Location') AS location_name
        FROM quest_completions qc
        JOIN quests q ON qc.quest_id = q.id
        WHERE qc.user_id = :uid AND qc.status = 'verified'
        ORDER BY qc.completed_at DESC
        ''',
        {'uid': targetId},
      );

      if (qRes != null) {
        return qRes.rows.map((row) {
          final map = row.assoc();
          return FriendCompletedQuestSummaryModel(
            questId: map['quest_id'] ?? '',
            title: map['title'] ?? 'Adventure Quest',
            category: map['category'] ?? 'Exploration',
            xpEarned: int.tryParse(map['xp_earned'] ?? '50') ?? 50,
            coinsEarned: int.tryParse(map['coins_earned'] ?? '25') ?? 25,
            completedAt: DateTime.tryParse(map['completed_at'] ?? '') ?? DateTime.now(),
            locationName: map['location_name'] ?? 'Landmark',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[FriendsRemoteDataSource] Fallback getFriendHistory error: $e');
    }

    return [];
  }

  @override
  Future<void> removeFriend({
    required String currentUserId,
    required String friendUserId,
  }) async {
    // 1. Try PHP REST API
    final restResponse = await _callRestApi(
      'friends/remove_friend.php',
      method: 'POST',
      body: {
        'user_id': currentUserId,
        'friend_user_id': friendUserId,
      },
    );

    if (restResponse != null && restResponse['success'] == true) {
      return;
    }

    // 2. Direct MySQL Fallback
    final connected = await _dbService.connect();
    if (!connected) return;

    try {
      await _dbService.execute(
        '''
        UPDATE friend_requests
        SET status = 'cancelled', updated_at = NOW()
        WHERE ((sender_id = :u1 AND receiver_id = :f1) OR (sender_id = :f2 AND receiver_id = :u2))
        ''',
        {'u1': currentUserId, 'f1': friendUserId, 'f2': friendUserId, 'u2': currentUserId},
      );
      await _dbService.execute(
        '''
        DELETE FROM user_friends
        WHERE (user_id = :u1 AND friend_id = :f1) OR (user_id = :f2 AND friend_id = :u2)
        ''',
        {'u1': currentUserId, 'f1': friendUserId, 'f2': friendUserId, 'u2': currentUserId},
      );
    } catch (e) {
      debugPrint('[FriendsRemoteDataSource] Fallback removeFriend error: $e');
    }
  }

  @override
  Future<List<FriendProfileModel>> getSuggestedPlayers({required String currentUserId}) async {
    final restResp = await _callRestApi(
      'friends/list_players.php',
      queryParams: {
        'current_user_id': currentUserId,
        'limit': '25',
      },
    );

    if (restResp != null && restResp['success'] == true) {
      final list = restResp['players'] as List? ?? [];
      return list.map((item) => _mapJsonToFriendProfile(item as Map<String, dynamic>)).toList();
    }

    // Direct MySQL Fallback
    final connected = await _dbService.connect();
    if (!connected) return [];

    try {
      final res = await _dbService.execute(
        '''
        SELECT 
          u.id,
          u.player_id,
          u.name AS username,
          COALESCE(up.name, u.name) AS display_name,
          COALESCE(up.avatar_key, 'avatar_1') AS avatar_url,
          COALESCE(up.level, 1) AS level,
          COALESCE(up.current_xp, 0) AS xp,
          COALESCE(up.coins, 100) AS coins,
          (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE u.id != :self_id 
          AND u.player_id IS NOT NULL 
          AND u.player_id != ''
        ORDER BY u.created_at DESC
        LIMIT 25
        ''',
        {'self_id': currentUserId},
      );

      if (res != null) {
        return res.rows.map((row) {
          return _mapRowToFriendProfile(row.assoc(), 'QST-0000');
        }).toList();
      }
    } catch (e) {
      debugPrint('[FriendsRemoteDataSource] Fallback getSuggestedPlayers error: $e');
    }

    return [];
  }

  FriendProfileModel _mapJsonToFriendProfile(Map<String, dynamic> json, {bool? forceFriend}) {
    final status = json['friendship_status'] as String? ?? ((forceFriend == true || json['is_friend'] == true) ? 'accepted' : 'none');
    final isFriend = forceFriend ?? (status == 'accepted' || json['is_friend'] == true);

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
      isFriend: isFriend,
      friendshipStatus: status,
    );
  }

  FriendProfileModel _mapRowToFriendProfile(
    Map<String, String?> row,
    String fallbackTag, {
    bool isFriend = false,
    String friendshipStatus = 'none',
  }) {
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
      isFriend: isFriend,
      friendshipStatus: friendshipStatus,
    );
  }
}
