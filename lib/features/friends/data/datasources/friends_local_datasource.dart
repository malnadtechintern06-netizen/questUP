import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/friends/data/models/friend_request_model.dart';

abstract class IFriendsLocalDataSource {
  Future<List<FriendProfileModel>> getFriends();
  Future<void> saveFriends(List<FriendProfileModel> friends);

  Future<List<FriendRequestModel>> getFriendRequests();
  Future<void> saveFriendRequests(List<FriendRequestModel> requests);

  Future<List<FriendProfileModel>> getPlayerRegistry();
  Future<void> savePlayerRegistry(List<FriendProfileModel> players);

  String computePlayerTag(String userId, [String? email]);
}

class FriendsLocalDataSource implements IFriendsLocalDataSource {
  final ILocalStorageService _storage;

  FriendsLocalDataSource(this._storage);

  @override
  String computePlayerTag(String userId, [String? email]) {
    // Generate a clean memorable player tag like QST-4821
    final source = email != null && email.isNotEmpty ? email : userId;
    final bytes = utf8.encode(source);
    final hash = sha256.convert(bytes).toString();
    final numberPart = int.parse(hash.substring(0, 4), radix: 16) % 9000 + 1000;
    return 'QST-$numberPart';
  }

  Future<String> _getActiveUserId() async {
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      if (authSession != null && authSession is Map<String, dynamic>) {
        return authSession['id']?.toString() ?? 'guest_player';
      }
    } catch (_) {}
    return 'guest_player';
  }

  @override
  Future<List<FriendProfileModel>> getFriends() async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friends_${userId}_v1';
    final raw = await _storage.getJson(userSpecificKey);
    if (raw is List) {
      return raw
          .map((item) => FriendProfileModel.fromJson(item as Map<String, dynamic>))
          .where((f) => !f.userId.startsWith('comp_') && !f.userId.startsWith('player_QST-'))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveFriends(List<FriendProfileModel> friends) async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friends_${userId}_v1';
    final sanitized = friends
        .where((f) => !f.userId.startsWith('comp_') && !f.userId.startsWith('player_QST-'))
        .map((f) => f.toJson())
        .toList();
    await _storage.saveJson(userSpecificKey, sanitized);
    await _storage.saveJson(AppConstants.keyFriends, sanitized);
  }

  @override
  Future<List<FriendRequestModel>> getFriendRequests() async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friend_requests_${userId}_v1';
    final raw = await _storage.getJson(userSpecificKey);
    if (raw is List) {
      return raw
          .map((item) => FriendRequestModel.fromJson(item as Map<String, dynamic>))
          .where((r) => !r.senderId.startsWith('comp_') && !r.senderId.startsWith('player_QST-'))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveFriendRequests(List<FriendRequestModel> requests) async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friend_requests_${userId}_v1';
    final sanitized = requests
        .where((r) => !r.senderId.startsWith('comp_') && !r.senderId.startsWith('player_QST-'))
        .map((r) => r.toJson())
        .toList();
    await _storage.saveJson(userSpecificKey, sanitized);
    await _storage.saveJson(AppConstants.keyFriendRequests, sanitized);
  }

  @override
  Future<List<FriendProfileModel>> getPlayerRegistry() async {
    final raw = await _storage.getJson(AppConstants.keyPlayerRegistry);
    List<FriendProfileModel> players = [];
    if (raw is List) {
      players = raw
          .map((item) => FriendProfileModel.fromJson(item as Map<String, dynamic>))
          .where((p) => !p.userId.startsWith('comp_') && !p.userId.startsWith('player_QST-'))
          .toList();
    }

    // Merge any locally registered users
    final localUsersRaw = await _storage.getJson(AppConstants.keyLocalUsers);
    if (localUsersRaw is Map<String, dynamic>) {
      for (final entry in localUsersRaw.entries) {
        final data = entry.value;
        if (data is Map<String, dynamic>) {
          final userId = data['id'] as String? ?? entry.key;
          if (userId.startsWith('comp_') || userId.startsWith('player_QST-')) continue;

          final userName = data['name'] as String? ?? entry.key.split('@').first;
          final userTag = data['player_id'] as String? ?? computePlayerTag(userId, entry.key);

          final exists = players.any((p) => p.userId == userId || p.playerTag == userTag);
          if (!exists) {
            players.add(
              FriendProfileModel(
                userId: userId,
                playerTag: userTag,
                name: userName,
                avatarKey: data['avatar_key'] as String? ?? 'avatar_1',
                level: int.tryParse(data['level']?.toString() ?? '1') ?? 1,
                currentXp: int.tryParse(data['current_xp']?.toString() ?? '0') ?? 0,
                coins: int.tryParse(data['coins']?.toString() ?? '100') ?? 100,
                rank: players.length + 1,
                rankTitle: 'Explorer Scout',
                completedQuestsCount: 0,
                gamesPlayedCount: 0,
                completedQuests: const [],
                earnedBadges: const [],
                friendshipDate: DateTime.now(),
                isOnline: true,
                lastActiveText: 'Active on Radar',
                isFriend: false,
                friendshipStatus: 'none',
              ),
            );
          }
        }
      }
    }

    return players;
  }

  @override
  Future<void> savePlayerRegistry(List<FriendProfileModel> players) async {
    final sanitized = players
        .where((p) => !p.userId.startsWith('comp_') && !p.userId.startsWith('player_QST-'))
        .map((p) => p.toJson())
        .toList();
    await _storage.saveJson(AppConstants.keyPlayerRegistry, sanitized);
  }
}
