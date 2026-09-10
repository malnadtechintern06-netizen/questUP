import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/features/friends/data/datasources/friends_local_datasource.dart';
import 'package:quest_up/features/friends/data/datasources/friends_remote_datasource.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/friends/data/models/friend_request_model.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';
import 'package:quest_up/features/friends/domain/repositories/friends_repository.dart';
import 'package:quest_up/features/profile/domain/repositories/user_repository.dart';

class FriendsRepositoryImpl implements IFriendsRepository {
  final IFriendsLocalDataSource localDataSource;
  final IFriendsRemoteDataSource? remoteDataSource;
  final UserRepository userRepository;

  FriendsRepositoryImpl({
    required this.localDataSource,
    this.remoteDataSource,
    required this.userRepository,
  });

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

  @override
  Future<String> getMyPlayerTag() async {
    final profile = await userRepository.getUserProfile();
    if (profile.playerId.isNotEmpty && RegExp(r'^QST-\d{4}$', caseSensitive: false).hasMatch(profile.playerId)) {
      return profile.playerId.toUpperCase();
    }
    return localDataSource.computePlayerTag(profile.id, profile.email);
  }

  @override
  Future<List<FriendProfile>> getFriends() async {
    final localFriends = await localDataSource.getFriends();
    if (remoteDataSource != null) {
      try {
        final profile = await userRepository.getUserProfile();
        final remoteFriends = await remoteDataSource!.getFriends(profile.id);
        if (remoteFriends.isNotEmpty) {
          final existingIds = localFriends.map((f) => f.userId).toSet();
          for (final rf in remoteFriends) {
            if (!existingIds.contains(rf.userId)) {
              localFriends.add(rf);
            }
          }
          await localDataSource.saveFriends(localFriends);
        }
      } catch (_) {}
    }
    return localFriends;
  }

  @override
  Future<List<FriendRequest>> getPendingIncomingRequests() async {
    final allRequests = await localDataSource.getFriendRequests();
    final myTag = await getMyPlayerTag();
    final profile = await userRepository.getUserProfile();

    if (remoteDataSource != null) {
      try {
        final remoteRequests = await remoteDataSource!.getIncomingRequests(profile.id);
        final existingIds = allRequests.map((r) => r.id).toSet();
        for (final rr in remoteRequests) {
          if (!existingIds.contains(rr.id)) {
            allRequests.add(rr);
          }
        }
        await localDataSource.saveFriendRequests(allRequests);
      } catch (_) {}
    }

    return allRequests
        .where((r) =>
            r.status == FriendRequestStatus.pending &&
            (r.receiverId == profile.id ||
                r.receiverId == 'current_user' ||
                r.receiverTag.toUpperCase() == myTag.toUpperCase()))
        .toList();
  }

  @override
  Future<List<FriendRequest>> getSentRequests() async {
    final allRequests = await localDataSource.getFriendRequests();
    final profile = await userRepository.getUserProfile();

    if (remoteDataSource != null) {
      try {
        final remoteSent = await remoteDataSource!.getOutgoingRequests(profile.id);
        final existingIds = allRequests.map((r) => r.id).toSet();
        for (final rs in remoteSent) {
          if (!existingIds.contains(rs.id)) {
            allRequests.add(rs);
          }
        }
        await localDataSource.saveFriendRequests(allRequests);
      } catch (_) {}
    }

    return allRequests
        .where((r) =>
            r.status == FriendRequestStatus.pending &&
            (r.senderId == profile.id || r.senderId == 'current_user'))
        .toList();
  }

  @override
  Future<FriendRequest> sendFriendRequest({required String targetPlayerTagOrId}) async {
    final cleanQuery = targetPlayerTagOrId.trim();
    if (cleanQuery.isEmpty) {
      throw const AppException('Please enter a valid Player ID or Tag (e.g. QST-1108).');
    }

    final normalizedTag = _normalizeTag(cleanQuery);
    final myProfile = await userRepository.getUserProfile();
    final myTag = await getMyPlayerTag();

    // Check if target matches self
    if (normalizedTag == myTag.toUpperCase() ||
        cleanQuery.toUpperCase() == myTag.toUpperCase() ||
        cleanQuery == myProfile.id ||
        cleanQuery.toUpperCase() == myProfile.name.toUpperCase() ||
        cleanQuery.toUpperCase() == myProfile.email.toUpperCase()) {
      throw const AppException('You cannot send a friend request to yourself.');
    }

    // 1. Search player first (Remote MySQL / PHP REST API + Local fallback)
    final targetPlayer = await searchPlayer(cleanQuery);

    if (targetPlayer == null) {
      throw AppException(
        'Player "$targetPlayerTagOrId" not found. Please check the Player Tag (e.g. QST-1108) and try again.',
      );
    }

    // Check if already friends
    final currentFriends = await localDataSource.getFriends();
    if (currentFriends.any((f) => f.userId == targetPlayer.userId)) {
      throw AppException('${targetPlayer.name} is already in your squad friends list.');
    }

    // Check if duplicate pending request exists in local cache
    final requests = await localDataSource.getFriendRequests();
    final isAlreadySent = requests.any((r) =>
        r.status == FriendRequestStatus.pending &&
        (r.receiverId == targetPlayer.userId || r.receiverTag == targetPlayer.playerTag) &&
        (r.senderId == myProfile.id || r.senderId == 'current_user'));

    if (isAlreadySent) {
      throw AppException('A friend request to ${targetPlayer.name} is already pending.');
    }

    FriendRequestModel? newRequest;

    // 2. Dispatch to remote backend/MySQL
    if (remoteDataSource != null) {
      try {
        newRequest = await remoteDataSource!.sendFriendRequest(
          senderId: myProfile.id,
          targetTagOrId: targetPlayer.playerTag,
          senderTag: myTag,
          senderName: myProfile.name,
          senderEmail: myProfile.email,
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('already') || msg.contains('yourself')) {
          if (e is AppException) rethrow;
        }
        debugPrint('[FriendsRepo] Remote request dispatch fallback to local: $e');
      }
    }

    newRequest ??= FriendRequestModel(
      id: const Uuid().v4(),
      senderId: myProfile.id,
      senderName: myProfile.name,
      senderTag: myTag,
      senderAvatarKey: myProfile.avatarKey,
      senderLevel: myProfile.level,
      receiverId: targetPlayer.userId,
      receiverTag: targetPlayer.playerTag,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    requests.add(newRequest);
    await localDataSource.saveFriendRequests(requests);
    return newRequest;
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    final requests = await localDataSource.getFriendRequests();
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index == -1) {
      throw const AppException('Friend request not found.');
    }

    final req = requests[index];
    requests[index] = req.copyWith(status: FriendRequestStatus.accepted);
    await localDataSource.saveFriendRequests(requests);

    final myProfile = await userRepository.getUserProfile();
    if (remoteDataSource != null) {
      try {
        await remoteDataSource!
            .respondToFriendRequest(
              requestId: requestId,
              action: 'accept',
              currentUserId: myProfile.id,
            )
            .timeout(const Duration(milliseconds: 1500), onTimeout: () {});
      } catch (_) {}
    }

    // Add sender to friends list
    final registry = await localDataSource.getPlayerRegistry();
    FriendProfileModel? friendProfile =
        registry.where((p) => p.userId == req.senderId || p.playerTag.toUpperCase() == req.senderTag.toUpperCase()).firstOrNull;

    friendProfile ??= FriendProfileModel(
      userId: req.senderId,
      playerTag: req.senderTag,
      name: req.senderName,
      avatarKey: req.senderAvatarKey,
      level: req.senderLevel,
      currentXp: req.senderLevel * 500,
      coins: req.senderLevel * 200,
      rank: 6,
      rankTitle: 'Explorer Scout',
      completedQuestsCount: req.senderLevel * 2,
      gamesPlayedCount: req.senderLevel * 2 + 1,
      completedQuests: const [],
      earnedBadges: const [],
      friendshipDate: DateTime.now(),
      isOnline: true,
      lastActiveText: 'Active on Radar',
      isFriend: true,
      friendshipStatus: 'accepted',
    );

    final acceptedFriend = friendProfile.copyWith(
      isFriend: true,
      friendshipStatus: 'accepted',
      friendshipDate: DateTime.now(),
    );

    final currentFriends = await localDataSource.getFriends();
    final friendIndex = currentFriends.indexWhere(
      (f) => f.userId == acceptedFriend.userId || f.playerTag.toUpperCase() == acceptedFriend.playerTag.toUpperCase(),
    );
    if (friendIndex >= 0) {
      currentFriends[friendIndex] = acceptedFriend;
    } else {
      currentFriends.add(acceptedFriend);
    }
    await localDataSource.saveFriends(currentFriends);

    // Also update player registry
    final regIndex = registry.indexWhere(
      (p) => p.userId == acceptedFriend.userId || p.playerTag.toUpperCase() == acceptedFriend.playerTag.toUpperCase(),
    );
    if (regIndex >= 0) {
      registry[regIndex] = acceptedFriend;
    } else {
      registry.add(acceptedFriend);
    }
    await localDataSource.savePlayerRegistry(registry);
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    final requests = await localDataSource.getFriendRequests();
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = requests[index];
      requests[index] = req.copyWith(status: FriendRequestStatus.rejected);
      await localDataSource.saveFriendRequests(requests);
    }

    final myProfile = await userRepository.getUserProfile();
    if (remoteDataSource != null) {
      try {
        await remoteDataSource!
            .respondToFriendRequest(
              requestId: requestId,
              action: 'reject',
              currentUserId: myProfile.id,
            )
            .timeout(const Duration(milliseconds: 1500), onTimeout: () {});
      } catch (_) {}
    }
  }

  @override
  Future<void> removeFriend(String friendUserId) async {
    final currentFriends = await localDataSource.getFriends();
    currentFriends.removeWhere((f) => f.userId == friendUserId || f.playerTag.toUpperCase() == friendUserId.toUpperCase());
    await localDataSource.saveFriends(currentFriends);

    final myProfile = await userRepository.getUserProfile();
    if (remoteDataSource != null) {
      try {
        await remoteDataSource!.removeFriend(
          currentUserId: myProfile.id,
          friendUserId: friendUserId,
        );
      } catch (_) {}
    }
  }

  @override
  Future<FriendProfile?> getFriendProfile(String friendUserId) async {
    final myProfile = await userRepository.getUserProfile();
    final friends = await getFriends();
    final matchInFriends = friends.where((f) => f.userId == friendUserId || f.playerTag.toUpperCase() == friendUserId.toUpperCase()).firstOrNull;

    if (matchInFriends != null) {
      // User is an accepted friend! Fetch verified quest history
      List<FriendCompletedQuestSummary> history = matchInFriends.completedQuests;
      if (remoteDataSource != null) {
        try {
          final remoteHistory = await remoteDataSource!.getFriendHistory(
            currentUserId: myProfile.id,
            targetPlayerIdOrUserId: matchInFriends.playerTag.isNotEmpty ? matchInFriends.playerTag : matchInFriends.userId,
          );
          if (remoteHistory.isNotEmpty) {
            history = remoteHistory;
          }
        } catch (_) {}
      }
      return matchInFriends.copyWith(
        isFriend: true,
        friendshipStatus: 'accepted',
        completedQuests: history,
      );
    }

    // Check sent / incoming requests to know friendshipStatus
    final pendingIncoming = await getPendingIncomingRequests();
    final isPendingIncoming = pendingIncoming.any((r) => r.senderId == friendUserId || r.senderTag.toUpperCase() == friendUserId.toUpperCase());

    final pendingSent = await getSentRequests();
    final isPendingSent = pendingSent.any((r) => r.receiverId == friendUserId || r.receiverTag.toUpperCase() == friendUserId.toUpperCase());

    final status = isPendingIncoming ? 'pending_received' : (isPendingSent ? 'pending_sent' : 'none');

    // Not an accepted friend. Check local registry or remote search
    FriendProfile? profile;
    final registry = await localDataSource.getPlayerRegistry();
    profile = registry.where((p) => p.userId == friendUserId || p.playerTag.toUpperCase() == friendUserId.toUpperCase()).firstOrNull;

    if (profile == null && remoteDataSource != null) {
      try {
        profile = await remoteDataSource!.searchPlayer(friendUserId, currentUserId: myProfile.id);
      } catch (_) {}
    }

    if (profile != null) {
      // STRICT PRIVACY: For non-friends, completed quests must NEVER be shown!
      return profile.copyWith(
        isFriend: false,
        friendshipStatus: status,
        completedQuests: const [],
      );
    }

    return null;
  }

  @override
  Future<FriendProfile?> searchPlayer(String query) async {
    var cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;
    if (cleanQuery.startsWith('#')) {
      cleanQuery = cleanQuery.substring(1).trim();
    }

    final normalizedTag = _normalizeTag(cleanQuery);
    final myProfile = await userRepository.getUserProfile();
    final myTag = await getMyPlayerTag();

    // Check if user is searching for themselves
    if (normalizedTag == myTag.toUpperCase() ||
        cleanQuery.toUpperCase() == myTag.toUpperCase() ||
        cleanQuery == myProfile.id ||
        cleanQuery.toUpperCase() == myProfile.name.toUpperCase() ||
        cleanQuery.toUpperCase() == myProfile.email.toUpperCase()) {
      throw const AppException('This is your own Player ID. You cannot add yourself as a friend.');
    }

    // 1. Try Remote MySQL / PHP REST search first (fast parallel race with 1500ms timeout)
    if (remoteDataSource != null) {
      try {
        final remotePlayer = await remoteDataSource!
            .searchPlayer(cleanQuery, currentUserId: myProfile.id)
            .timeout(const Duration(milliseconds: 3000), onTimeout: () => null);

        if (remotePlayer != null) {
          // Cache in local player registry
          final registry = await localDataSource.getPlayerRegistry();
          final existingIdx = registry.indexWhere((p) =>
              p.userId == remotePlayer.userId ||
              p.playerTag.toUpperCase() == remotePlayer.playerTag.toUpperCase());
          if (existingIdx >= 0) {
            registry[existingIdx] = remotePlayer;
          } else {
            registry.add(remotePlayer);
          }
          await localDataSource.savePlayerRegistry(registry);
          return remotePlayer;
        }
      } catch (e) {
        if (e is AppException) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('own player id') || msg.contains('yourself')) {
            rethrow;
          }
        }
        debugPrint('[FriendsRepo] Remote search notice: $e');
      }
    }

    // 2. Search local player registry (Filter out any synthetic dummy entries)
    final registry = await localDataSource.getPlayerRegistry();
    final validRegistry = registry
        .where((p) => !p.userId.startsWith('player_QST-') && !p.userId.startsWith('comp_'))
        .toList();
    if (validRegistry.length != registry.length) {
      await localDataSource.savePlayerRegistry(validRegistry);
    }

    final qUpper = cleanQuery.toUpperCase();
    for (final player in validRegistry) {
      final pTag = player.playerTag.toUpperCase();
      final pName = player.name.toUpperCase();
      final pId = player.userId.toUpperCase();

      if (pTag == normalizedTag ||
          pTag == qUpper ||
          pId == qUpper ||
          pName == qUpper ||
          (cleanQuery.length >= 3 && pName.contains(qUpper))) {
        if (player.userId == myProfile.id) {
          throw const AppException('This is your own Player ID. You cannot add yourself as a friend.');
        }
        return player;
      }
    }

    // Return null if player not found anywhere
    return null;
  }

  @override
  Future<List<FriendProfile>> getSuggestedPlayers() async {
    final friends = await localDataSource.getFriends();
    final friendIds = friends.map((f) => f.userId).toSet();
    final myProfile = await userRepository.getUserProfile();
    final myTag = await getMyPlayerTag();

    final result = <FriendProfile>[];
    final seenIds = <String>{myProfile.id, ...friendIds};
    final seenTags = <String>{myTag.toUpperCase()};

    // 1. Fetch real players from MySQL database via REST API or direct service
    if (remoteDataSource != null) {
      try {
        final remote = await remoteDataSource!
            .getSuggestedPlayers(currentUserId: myProfile.id)
            .timeout(const Duration(milliseconds: 2500), onTimeout: () => []);
        for (final p in remote) {
          final tagUpper = p.playerTag.toUpperCase();
          if (!seenIds.contains(p.userId) && !seenTags.contains(tagUpper)) {
            seenIds.add(p.userId);
            seenTags.add(tagUpper);
            result.add(p);
          }
        }
      } catch (e) {
        debugPrint('[FriendsRepo] Remote suggested players notice: $e');
      }
    }

    // 2. Add local registry players if needed
    final registry = await localDataSource.getPlayerRegistry();
    for (final p in registry.where((p) => !p.userId.startsWith('player_QST-') && !p.userId.startsWith('comp_'))) {
      final tagUpper = p.playerTag.toUpperCase();
      if (!seenIds.contains(p.userId) && !seenTags.contains(tagUpper)) {
        seenIds.add(p.userId);
        seenTags.add(tagUpper);
        result.add(p);
      }
    }

    return result;
  }
}
