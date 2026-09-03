import '../entities/friend_profile.dart';
import '../entities/friend_request.dart';

abstract class IFriendsRepository {
  Future<List<FriendProfile>> getFriends();
  Future<List<FriendRequest>> getPendingIncomingRequests();
  Future<List<FriendRequest>> getSentRequests();
  Future<FriendRequest> sendFriendRequest({required String targetPlayerTagOrId});
  Future<void> acceptFriendRequest(String requestId);
  Future<void> rejectFriendRequest(String requestId);
  Future<void> removeFriend(String friendUserId);
  Future<FriendProfile?> getFriendProfile(String friendUserId);
  Future<FriendProfile?> searchPlayer(String query);
  Future<String> getMyPlayerTag();
  Future<List<FriendProfile>> getSuggestedPlayers();
}
