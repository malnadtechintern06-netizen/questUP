import 'package:uuid/uuid.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/features/friends/data/datasources/friends_local_datasource.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/friends/data/models/friend_request_model.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';
import 'package:quest_up/features/friends/domain/repositories/friends_repository.dart';
import 'package:quest_up/features/profile/domain/repositories/user_repository.dart';

class FriendsRepositoryImpl implements IFriendsRepository {
  final IFriendsLocalDataSource localDataSource;
  final UserRepository userRepository;

  FriendsRepositoryImpl({
    required this.localDataSource,
    required this.userRepository,
  });

  @override
  Future<String> getMyPlayerTag() async {
    final profile = await userRepository.getUserProfile();
    return localDataSource.computePlayerTag(profile.id, profile.email);
  }

  @override
  Future<List<FriendProfile>> getFriends() async {
    return await localDataSource.getFriends();
  }

  @override
  Future<List<FriendRequest>> getPendingIncomingRequests() async {
    final allRequests = await localDataSource.getFriendRequests();
    final myTag = await getMyPlayerTag();
    final profile = await userRepository.getUserProfile();

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

    return allRequests
        .where((r) =>
            r.status == FriendRequestStatus.pending &&
            (r.senderId == profile.id || r.senderId == 'current_user'))
        .toList();
  }

  @override
  Future<FriendRequest> sendFriendRequest({required String targetPlayerTagOrId}) async {
    final cleanQuery = targetPlayerTagOrId.trim().toUpperCase();
    if (cleanQuery.isEmpty) {
      throw const AppException('Please enter a valid Player ID or Tag (e.g. QST-1001).');
    }

    final myProfile = await userRepository.getUserProfile();
    final myTag = await getMyPlayerTag();

    // Check if target matches self
    if (cleanQuery == myTag.toUpperCase() ||
        cleanQuery == myProfile.id.toUpperCase() ||
        cleanQuery == myProfile.email.toUpperCase()) {
      throw const AppException('You cannot send a friend request to yourself.');
    }

    // Find target player in registry
    final registry = await localDataSource.getPlayerRegistry();
    FriendProfileModel? targetPlayer;
    for (final player in registry) {
      if (player.playerTag.toUpperCase() == cleanQuery ||
          player.userId.toUpperCase() == cleanQuery ||
          player.name.toUpperCase() == cleanQuery) {
        targetPlayer = player;
        break;
      }
    }

    if (targetPlayer == null) {
      throw AppException(
        'Player "$targetPlayerTagOrId" not found. Please check the Player Tag (e.g. QST-1001) and try again.',
      );
    }

    // Check if already friends
    final currentFriends = await localDataSource.getFriends();
    if (currentFriends.any((f) => f.userId == targetPlayer!.userId)) {
      throw AppException('${targetPlayer.name} is already in your squad friends list.');
    }

    // Check if duplicate pending request exists
    final requests = await localDataSource.getFriendRequests();
    final isAlreadySent = requests.any((r) =>
        r.status == FriendRequestStatus.pending &&
        (r.receiverId == targetPlayer!.userId || r.receiverTag == targetPlayer.playerTag) &&
        (r.senderId == myProfile.id || r.senderId == 'current_user'));

    if (isAlreadySent) {
      throw AppException('A friend request to ${targetPlayer.name} is already pending.');
    }

    final newRequest = FriendRequestModel(
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
    requests[index] = req.copyWith(status: FriendRequestStatus.accepted) as FriendRequestModel;
    await localDataSource.saveFriendRequests(requests);

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
      completedQuests: [],
      earnedBadges: [],
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
      requests[index] = req.copyWith(status: FriendRequestStatus.rejected) as FriendRequestModel;
      await localDataSource.saveFriendRequests(requests);
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
    return registry.where((p) => p.userId == friendUserId || p.playerTag == friendUserId).firstOrNull;
  }

  @override
  Future<FriendProfile?> searchPlayer(String query) async {
    final cleanQuery = query.trim().toUpperCase();
    if (cleanQuery.isEmpty) return null;

    final registry = await localDataSource.getPlayerRegistry();
    for (final player in registry) {
      if (player.playerTag.toUpperCase() == cleanQuery ||
          player.userId.toUpperCase() == cleanQuery ||
          player.name.toUpperCase().contains(cleanQuery)) {
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
