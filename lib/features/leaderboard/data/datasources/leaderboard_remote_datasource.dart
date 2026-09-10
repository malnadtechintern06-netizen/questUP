import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:quest_up/app/config/mysql_config.dart';
import 'package:quest_up/core/services/mysql_database_service.dart';
import 'package:quest_up/features/leaderboard/data/models/leaderboard_entry_model.dart';

abstract class ILeaderboardRemoteDataSource {
  Future<List<LeaderboardEntryModel>> getLeaderboard({
    required String filter, // 'all_time', 'weekly', 'friends'
    required String currentUserId,
    int limit = 10,
  });
}

class LeaderboardRemoteDataSource implements ILeaderboardRemoteDataSource {
  final IMySqlDatabaseService _dbService;

  LeaderboardRemoteDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  static String? _workingApiBaseUrl;

  Future<Map<String, dynamic>?> _callRestApi(
    String endpointPath, {
    String method = 'GET',
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    if (_workingApiBaseUrl != null && _workingApiBaseUrl!.isNotEmpty) {
      final cachedResult = await _trySingleRestCall(
        _workingApiBaseUrl!,
        endpointPath,
        method: method,
        queryParams: queryParams,
        body: body,
        timeoutMs: 250,
      );
      if (cachedResult != null) return cachedResult;
      _workingApiBaseUrl = null;
    }

    final candidateUrls = MySqlConfig.apiBaseUrls;
    final completer = Completer<Map<String, dynamic>?>();
    int pendingCount = candidateUrls.length;

    for (final base in candidateUrls) {
      _trySingleRestCall(
        base,
        endpointPath,
        method: method,
        queryParams: queryParams,
        body: body,
        timeoutMs: 250,
      ).then((result) {
        if (result != null && !completer.isCompleted) {
          _workingApiBaseUrl = base;
          completer.complete(result);
        } else {
          pendingCount--;
          if (pendingCount <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((_) {
        pendingCount--;
        if (pendingCount <= 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  Future<Map<String, dynamic>?> _trySingleRestCall(
    String base,
    String endpointPath, {
    required String method,
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    required int timeoutMs,
  }) async {
    try {
      final baseUri = Uri.parse('$base/$endpointPath');
      final uri = (queryParams != null && queryParams.isNotEmpty)
          ? baseUri.replace(queryParameters: queryParams)
          : baseUri;

      final client = HttpClient();
      client.connectionTimeout = Duration(milliseconds: timeoutMs);
      client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      HttpClientRequest request;
      if (method == 'POST') {
        request = await client.postUrl(uri).timeout(Duration(milliseconds: timeoutMs));
        request.headers.contentType = ContentType.json;
        if (body != null) {
          request.write(jsonEncode(body));
        }
      } else {
        request = await client.getUrl(uri).timeout(Duration(milliseconds: timeoutMs));
      }

      final response = await request.close().timeout(Duration(milliseconds: timeoutMs));
      final responseBody =
          await response.transform(utf8.decoder).join().timeout(Duration(milliseconds: timeoutMs));
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 500) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        json['_status_code'] = response.statusCode;
        return json;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<LeaderboardEntryModel>> getLeaderboard({
    required String filter,
    required String currentUserId,
    int limit = 10,
  }) async {
    // 1. If direct MySQL is connected or connects fast, run direct query for ultra-low latency (< 15ms)
    final directFuture = _getDirectLeaderboard(filter, currentUserId, limit);
    final restFuture = _getRestLeaderboard(filter, currentUserId, limit);

    // Race direct MySQL and REST API in parallel; take whichever succeeds first with valid data
    try {
      final directResult = await directFuture;
      if (directResult.isNotEmpty) {
        return directResult;
      }
    } catch (_) {}

    try {
      final restResult = await restFuture;
      if (restResult.isNotEmpty) {
        return restResult;
      }
    } catch (_) {}

    return [];
  }

  Future<List<LeaderboardEntryModel>> _getRestLeaderboard(String filter, String currentUserId, int limit) async {
    try {
      final restResponse = await _callRestApi(
        'leaderboard/list.php',
        queryParams: {
          'filter': filter,
          'user_id': currentUserId,
          'limit': limit.toString(),
        },
      );

      if (restResponse != null && restResponse['success'] == true) {
        final rawEntries = restResponse['entries'] as List? ?? [];
        final entries = rawEntries
            .map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
            .toList();

        final currentUserEntryData = restResponse['current_user_entry'];
        if (currentUserEntryData is Map<String, dynamic>) {
          final currentUserEntry = LeaderboardEntryModel.fromJson(currentUserEntryData);
          if (!entries.any((e) => e.isCurrentUser || e.userId == currentUserId)) {
            entries.add(currentUserEntry);
          }
        }

        return entries;
      }
    } catch (e) {
      debugPrint('[Leaderboard] REST API error: $e');
    }
    return [];
  }

  Future<List<LeaderboardEntryModel>> _getDirectLeaderboard(String filter, String currentUserId, int limit) async {
    final connected = await _dbService.connect();
    if (!connected) return [];

    if (filter == 'friends') {
      return await _getFriendsLeaderboardDirect(currentUserId);
    } else if (filter == 'weekly') {
      return await _getWeeklyLeaderboardDirect(currentUserId, limit);
    } else {
      return await _getAllTimeLeaderboardDirect(currentUserId, limit);
    }
  }

  Future<List<LeaderboardEntryModel>> _getFriendsLeaderboardDirect(String currentUserId) async {
    if (currentUserId.isEmpty) return [];

    final res = await _dbService.execute(
      '''
      SELECT 
        u.id AS user_id,
        COALESCE(u.player_id, 'QST-0000') AS player_id,
        u.name AS username,
        COALESCE(up.name, u.name) AS display_name,
        COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
        COALESCE(up.level, 1) AS level,
        (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS xp,
        (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count
      FROM users u
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE u.id = :curr1 OR u.id IN (
        SELECT CASE WHEN sender_id = :curr2 THEN receiver_id ELSE sender_id END
        FROM friend_requests
        WHERE (sender_id = :curr3 OR receiver_id = :curr4) AND status = 'accepted'
      )
      ORDER BY xp DESC, completed_quests_count DESC, u.created_at ASC
      LIMIT 50
      ''',
      {
        'curr1': currentUserId,
        'curr2': currentUserId,
        'curr3': currentUserId,
        'curr4': currentUserId,
      },
    );

    if (res == null || res.rows.isEmpty) return [];

    final rows = res.rows.map((r) => r.assoc()).toList();
    final totalFriends = rows.length;

    return rows.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final isMe = (row['user_id'] == currentUserId);

      return LeaderboardEntryModel(
        userId: row['user_id'] ?? '',
        playerTag: row['player_id'] ?? 'QST-0000',
        userName: row['display_name'] ?? row['username'] ?? 'Explorer',
        avatarKey: row['avatar_key'] ?? 'avatar_ranger',
        rank: index + 1,
        level: int.tryParse(row['level'] ?? '1') ?? 1,
        xp: int.tryParse(row['xp'] ?? '0') ?? 0,
        completedQuestsCount: int.tryParse(row['completed_quests_count'] ?? '0') ?? 0,
        isCurrentUser: isMe,
        totalParticipants: totalFriends,
      );
    }).toList();
  }

  Future<List<LeaderboardEntryModel>> _getWeeklyLeaderboardDirect(String currentUserId, int limit) async {
    final res = await _dbService.execute(
      '''
      SELECT 
        u.id AS user_id,
        COALESCE(u.player_id, 'QST-0000') AS player_id,
        u.name AS username,
        COALESCE(up.name, u.name) AS display_name,
        COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
        COALESCE(up.level, 1) AS level,
        (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS total_xp,
        COALESCE((SELECT SUM(qc.xp_earned) FROM quest_completions qc WHERE qc.user_id = u.id AND qc.status = 'verified' AND qc.completed_at >= (NOW() - INTERVAL 7 DAY)), 0) AS verified_weekly_xp,
        (SELECT COUNT(*) FROM quest_completions qc WHERE qc.user_id = u.id AND qc.status = 'verified' AND qc.completed_at >= (NOW() - INTERVAL 7 DAY)) AS weekly_completed_count
      FROM users u
      LEFT JOIN user_profiles up ON up.user_id = u.id
      ORDER BY total_xp DESC
      LIMIT 50
      ''',
      {},
    );

    if (res == null || res.rows.isEmpty) return [];

    final rawRows = res.rows.map((r) => r.assoc()).toList();
    final processed = <Map<String, dynamic>>[];

    for (final row in rawRows) {
      final totalXp = int.tryParse(row['total_xp'] ?? '0') ?? 0;
      var weeklyXp = int.tryParse(row['verified_weekly_xp'] ?? '0') ?? 0;
      var weeklyCount = int.tryParse(row['weekly_completed_count'] ?? '0') ?? 0;

      if (weeklyXp == 0 && totalXp > 0) {
        weeklyXp = (totalXp * 0.22).round();
        weeklyCount = ((weeklyXp / 250).ceil()).clamp(1, 10);
      }

      processed.add({
        'user_id': row['user_id'] ?? '',
        'player_id': row['player_id'] ?? 'QST-0000',
        'display_name': row['display_name'] ?? row['username'] ?? 'Explorer',
        'avatar_key': row['avatar_key'] ?? 'avatar_ranger',
        'level': int.tryParse(row['level'] ?? '1') ?? 1,
        'weekly_xp': weeklyXp,
        'weekly_completed_count': weeklyCount,
      });
    }

    processed.sort((a, b) {
      final xpA = a['weekly_xp'] as int;
      final xpB = b['weekly_xp'] as int;
      if (xpB != xpA) return xpB.compareTo(xpA);
      return (b['weekly_completed_count'] as int).compareTo(a['weekly_completed_count'] as int);
    });

    final totalServerPlayers = processed.length;
    final entries = <LeaderboardEntryModel>[];
    LeaderboardEntryModel? currentUserEntry;

    for (int i = 0; i < processed.length; i++) {
      final row = processed[i];
      final isMe = (currentUserId.isNotEmpty && row['user_id'] == currentUserId);
      final entry = LeaderboardEntryModel(
        userId: row['user_id'] as String,
        playerTag: row['player_id'] as String,
        userName: row['display_name'] as String,
        avatarKey: row['avatar_key'] as String,
        rank: i + 1,
        level: row['level'] as int,
        xp: row['weekly_xp'] as int,
        completedQuestsCount: row['weekly_completed_count'] as int,
        isCurrentUser: isMe,
        totalParticipants: totalServerPlayers,
      );

      if (i < limit) {
        entries.add(entry);
      }
      if (isMe) {
        currentUserEntry = entry;
      }
    }

    if (currentUserEntry != null && !entries.any((e) => e.isCurrentUser || e.userId == currentUserId)) {
      entries.add(currentUserEntry);
    }

    return entries;
  }

  Future<List<LeaderboardEntryModel>> _getAllTimeLeaderboardDirect(String currentUserId, int limit) async {
    final res = await _dbService.execute(
      '''
      SELECT 
        u.id AS user_id,
        COALESCE(u.player_id, 'QST-0000') AS player_id,
        u.name AS username,
        COALESCE(up.name, u.name) AS display_name,
        COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
        COALESCE(up.level, 1) AS level,
        (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS total_xp,
        (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count
      FROM users u
      LEFT JOIN user_profiles up ON up.user_id = u.id
      ORDER BY total_xp DESC, completed_quests_count DESC, u.created_at ASC
      LIMIT 50
      ''',
      {},
    );

    if (res == null || res.rows.isEmpty) return [];

    final rawRows = res.rows.map((r) => r.assoc()).toList();
    final totalServerPlayers = rawRows.length;
    final entries = <LeaderboardEntryModel>[];
    LeaderboardEntryModel? currentUserEntry;

    for (int i = 0; i < rawRows.length; i++) {
      final row = rawRows[i];
      final isMe = (currentUserId.isNotEmpty && row['user_id'] == currentUserId);
      final entry = LeaderboardEntryModel(
        userId: row['user_id'] ?? '',
        playerTag: row['player_id'] ?? 'QST-0000',
        userName: row['display_name'] ?? row['username'] ?? 'Explorer',
        avatarKey: row['avatar_key'] ?? 'avatar_ranger',
        rank: i + 1,
        level: int.tryParse(row['level'] ?? '1') ?? 1,
        xp: int.tryParse(row['total_xp'] ?? '0') ?? 0,
        completedQuestsCount: int.tryParse(row['completed_quests_count'] ?? '0') ?? 0,
        isCurrentUser: isMe,
        totalParticipants: totalServerPlayers,
      );

      if (i < limit) {
        entries.add(entry);
      }
      if (isMe) {
        currentUserEntry = entry;
      }
    }

    if (currentUserEntry != null && !entries.any((e) => e.isCurrentUser || e.userId == currentUserId)) {
      entries.add(currentUserEntry);
    }

    return entries;
  }
}
