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
    final trimmed = query.trim().toUpperCase();
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
        );
      } catch (e) {
        if (e is AppException) rethrow;
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
        await remoteDataSource!.respondToFriendRequest(
          requestId: requestId,
          action: 'accept',
          currentUserId: myProfile.id,
        );
      } catch (_) {}
    }

    // Add sender to friends list
    final registry = await localDataSource.getPlayerRegistry();
    FriendProfileModel? friendProfile =
        registry.where((p) => p.userId == req.senderId || p.playerTag == req.senderTag).firstOrNull;

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
    );

    final currentFriends = await localDataSource.getFriends();
    if (!currentFriends.any((f) => f.userId == friendProfile!.userId)) {
      currentFriends.add(friendProfile);
      await localDataSource.saveFriends(currentFriends);
    }
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
        await remoteDataSource!.respondToFriendRequest(
          requestId: requestId,
          action: 'reject',
          currentUserId: myProfile.id,
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> removeFriend(String friendUserId) async {
    final currentFriends = await localDataSource.getFriends();
    currentFriends.removeWhere((f) => f.userId == friendUserId);
    await localDataSource.saveFriends(currentFriends);
  }

  @override
  Future<FriendProfile?> getFriendProfile(String friendUserId) async {
    final friends = await localDataSource.getFriends();
    final matchInFriends = friends.where((f) => f.userId == friendUserId).firstOrNull;
    if (matchInFriends != null) return matchInFriends;

    final registry = await localDataSource.getPlayerRegistry();
    final matchInRegistry = registry.where((p) => p.userId == friendUserId || p.playerTag == friendUserId).firstOrNull;
    if (matchInRegistry != null) return matchInRegistry;

    // Search via remote
    if (remoteDataSource != null) {
      try {
        final remoteMatch = await remoteDataSource!.searchPlayer(friendUserId);
        if (remoteMatch != null) return remoteMatch;
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<FriendProfile?> searchPlayer(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

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

    // 1. Try Remote MySQL / PHP REST search first
    if (remoteDataSource != null) {
      try {
        final remotePlayer = await remoteDataSource!.searchPlayer(
          cleanQuery,
          currentUserId: myProfile.id,
        );
        if (remotePlayer != null) {
          // Cache in local player registry
          final registry = await localDataSource.getPlayerRegistry();
          if (!registry.any((p) => p.userId == remotePlayer.userId)) {
            registry.add(remotePlayer);
            await localDataSource.savePlayerRegistry(registry);
          }
          return remotePlayer;
        }
      } catch (e) {
        if (e is AppException) rethrow;
      }
    }

    // 2. Search local player registry
    final registry = await localDataSource.getPlayerRegistry();
    for (final player in registry) {
      if (player.playerTag.toUpperCase() == normalizedTag ||
          player.playerTag.toUpperCase() == cleanQuery.toUpperCase() ||
          player.userId.toUpperCase() == cleanQuery.toUpperCase() ||
          player.name.toUpperCase() == cleanQuery.toUpperCase()) {
        if (player.userId == myProfile.id) {
          throw const AppException('This is your own Player ID. You cannot add yourself as a friend.');
        }
        return player;
      }
    }

    return null;
  }

  @override
  Future<List<FriendProfile>> getSuggestedPlayers() async {
    final friends = await localDataSource.getFriends();
    final friendIds = friends.map((f) => f.userId).toSet();
    final myProfile = await userRepository.getUserProfile();

    final registry = await localDataSource.getPlayerRegistry();
    return registry
        .where((p) => p.userId != myProfile.id && !friendIds.contains(p.userId))
        .toList();
  }
}
