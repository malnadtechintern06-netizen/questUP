import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/features/friends/data/models/friend_request_model.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';
import 'package:quest_up/features/profile/domain/entities/user_profile.dart';

class TestableFriendPrivacySystem {
  final Map<String, UserProfile> players = {};
  final List<FriendRequestModel> requests = [];
  final Map<String, List<FriendCompletedQuestSummary>> completedQuests = {};

  void registerPlayer(UserProfile p) {
    players[p.id] = p;
    completedQuests[p.id] = [];
  }

  void addQuestHistory(String userId, FriendCompletedQuestSummary quest) {
    completedQuests.putIfAbsent(userId, () => []).add(quest);
  }

  FriendRequestModel sendFriendRequest({required String senderId, required String targetTag}) {
    final sender = players[senderId];
    if (sender == null) throw const AppException('Sender not found');

    final target = players.values.firstWhere(
      (p) => p.playerId.toUpperCase() == targetTag.toUpperCase() || p.id == targetTag,
      orElse: () => throw AppException('Player $targetTag not found'),
    );

    if (sender.id == target.id || sender.playerId.toUpperCase() == target.playerId.toUpperCase()) {
      throw const AppException('You cannot send a friend request to yourself.');
    }

    final existing = requests.where((r) =>
      ((r.senderId == sender.id && r.receiverId == target.id) ||
       (r.senderId == target.id && r.receiverId == sender.id)) &&
      (r.status == FriendRequestStatus.pending || r.status == FriendRequestStatus.accepted)
    ).firstOrNull;

    if (existing != null) {
      if (existing.status == FriendRequestStatus.accepted) {
        throw const AppException('You are already friends with this player.');
      }
      throw const AppException('A pending friend request already exists between you and this player.');
    }

    final req = FriendRequestModel(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      senderId: sender.id,
      senderName: sender.name,
      senderTag: sender.playerId,
      senderAvatarKey: sender.avatarKey,
      senderLevel: sender.level,
      receiverId: target.id,
      receiverTag: target.playerId,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    requests.add(req);
    return req;
  }

  void acceptFriendRequest(String requestId, String currentUserId) {
    final idx = requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) throw const AppException('Request not found');
    final req = requests[idx];
    if (req.receiverId != currentUserId) throw const AppException('Only receiver can accept');

    requests[idx] = req.copyWith(status: FriendRequestStatus.accepted);
  }

  void rejectFriendRequest(String requestId, String currentUserId) {
    final idx = requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) throw const AppException('Request not found');
    final req = requests[idx];
    if (req.receiverId != currentUserId) throw const AppException('Only receiver can reject');

    requests[idx] = req.copyWith(status: FriendRequestStatus.rejected);
  }

  // Strict privacy history fetch (emulating backend/api/friends/history.php)
  Map<String, dynamic> getPlayerHistory({required String requesterId, required String targetPlayerTagOrId}) {
    final requester = players[requesterId];
    if (requester == null) {
      return {'statusCode': 401, 'success': false, 'error': 'Authenticated user session not found.'};
    }

    final target = players.values.firstWhere(
      (p) => p.playerId.toUpperCase() == targetPlayerTagOrId.toUpperCase() || p.id == targetPlayerTagOrId,
      orElse: () => throw const AppException('Target not found'),
    );

    // Own history bypass
    if (requester.id == target.id) {
      return {
        'statusCode': 200,
        'success': true,
        'is_own_history': true,
        'is_friend': true,
        'history': completedQuests[target.id] ?? [],
      };
    }

    // Mutual friendship check
    final isMutualFriend = requests.any((r) =>
      r.status == FriendRequestStatus.accepted &&
      ((r.senderId == requester.id && r.receiverId == target.id) ||
       (r.senderId == target.id && r.receiverId == requester.id))
    );

    if (!isMutualFriend) {
      return {
        'statusCode': 403,
        'success': false,
        'error': 'Players are not friends',
      };
    }

    return {
      'statusCode': 200,
      'success': true,
      'is_own_history': false,
      'is_friend': true,
      'history': completedQuests[target.id] ?? [],
    };
  }
}

void main() {
  group('QuestUP Player ID & Privacy System Tests', () {
    late TestableFriendPrivacySystem system;
    late UserProfile p1; // QST-2794
    late UserProfile p2; // QST-1409
    late UserProfile p3; // QST-8888 (3rd player non-friend)

    setUp(() {
      system = TestableFriendPrivacySystem();

      p1 = UserProfile(
        id: 'usr_p1',
        name: 'Player 1',
        email: 'p1@questup.app',
        playerId: 'QST-2794',
        avatarKey: 'avatar_1',
        level: 4,
        coins: 450,
        currentXp: 1200,
        xpToNextLevel: 2000,
        completedQuestIds: const [],
        earnedBadgeIds: const [],
        joinedAt: DateTime.now(),
      );

      p2 = UserProfile(
        id: 'usr_p2',
        name: 'Player 2',
        email: 'p2@questup.app',
        playerId: 'QST-1409',
        avatarKey: 'avatar_2',
        level: 3,
        coins: 300,
        currentXp: 900,
        xpToNextLevel: 1500,
        completedQuestIds: const [],
        earnedBadgeIds: const [],
        joinedAt: DateTime.now(),
      );

      p3 = UserProfile(
        id: 'usr_p3',
        name: 'Player 3',
        email: 'p3@questup.app',
        playerId: 'QST-8888',
        avatarKey: 'avatar_3',
        level: 2,
        coins: 200,
        currentXp: 500,
        xpToNextLevel: 1000,
        completedQuestIds: const [],
        earnedBadgeIds: const [],
        joinedAt: DateTime.now(),
      );

      system.registerPlayer(p1);
      system.registerPlayer(p2);
      system.registerPlayer(p3);

      // Add quest completions to Player 2
      system.addQuestHistory(
        p2.id,
        FriendCompletedQuestSummary(
          questId: 'q_citadel',
          title: 'Citadel Secrets Quest',
          category: 'Historical Landmark',
          xpEarned: 150,
          coinsEarned: 50,
          completedAt: DateTime.now(),
          locationName: 'Ancient Citadel',
        ),
      );

      // Add quest completions to Player 1
      system.addQuestHistory(
        p1.id,
        FriendCompletedQuestSummary(
          questId: 'q_forest',
          title: 'Whispering Forest Sprint',
          category: 'Nature',
          xpEarned: 200,
          coinsEarned: 80,
          completedAt: DateTime.now(),
          locationName: 'Highland Trail',
        ),
      );
    });

    test('1. Every player must have ONE permanent unique 4-digit Player ID', () {
      final idPattern = RegExp(r'^QST-\d{4}$');
      expect(idPattern.hasMatch(p1.playerId), isTrue);
      expect(idPattern.hasMatch(p2.playerId), isTrue);
      expect(idPattern.hasMatch(p3.playerId), isTrue);
      expect(p1.playerId, isNot(equals(p2.playerId)));
      expect(p2.playerId, isNot(equals(p3.playerId)));
    });

    test('2. Self-request is strictly blocked', () {
      expect(
        () => system.sendFriendRequest(senderId: p1.id, targetTag: 'QST-2794'),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('yourself'))),
      );
    });

    test('3. Privacy when status is NONE: HTTP 403 and access denied', () {
      final res = system.getPlayerHistory(requesterId: p1.id, targetPlayerTagOrId: p2.playerId);
      expect(res['statusCode'], equals(403));
      expect(res['success'], isFalse);
      expect(res['error'], equals('Players are not friends'));
    });

    test('4. Privacy when status is PENDING: history remains strictly locked in both directions', () {
      // QST-2794 sends friend request to QST-1409
      final req = system.sendFriendRequest(senderId: p1.id, targetTag: p2.playerId);
      expect(req.status, equals(FriendRequestStatus.pending));

      // QST-2794 tries to view QST-1409's history -> BLOCKED 403
      final p1ViewingP2 = system.getPlayerHistory(requesterId: p1.id, targetPlayerTagOrId: p2.playerId);
      expect(p1ViewingP2['statusCode'], equals(403));
      expect(p1ViewingP2['success'], isFalse);
      expect(p1ViewingP2['error'], equals('Players are not friends'));

      // QST-1409 tries to view QST-2794's history -> BLOCKED 403
      final p2ViewingP1 = system.getPlayerHistory(requesterId: p2.id, targetPlayerTagOrId: p1.playerId);
      expect(p2ViewingP1['statusCode'], equals(403));
      expect(p2ViewingP1['success'], isFalse);
      expect(p2ViewingP1['error'], equals('Players are not friends'));
    });

    test('5. Privacy when status is REJECTED: history remains locked in both directions', () {
      final req = system.sendFriendRequest(senderId: p1.id, targetTag: p2.playerId);
      system.rejectFriendRequest(req.id, p2.id);

      final p1ViewingP2 = system.getPlayerHistory(requesterId: p1.id, targetPlayerTagOrId: p2.playerId);
      expect(p1ViewingP2['statusCode'], equals(403));
      expect(p1ViewingP2['success'], isFalse);

      final p2ViewingP1 = system.getPlayerHistory(requesterId: p2.id, targetPlayerTagOrId: p1.playerId);
      expect(p2ViewingP1['statusCode'], equals(403));
      expect(p2ViewingP1['success'], isFalse);
    });

    test('6. Mutual friendship when ACCEPTED: both players can view verified quest history', () {
      final req = system.sendFriendRequest(senderId: p1.id, targetTag: p2.playerId);
      system.acceptFriendRequest(req.id, p2.id);

      // QST-2794 views QST-1409's history -> SUCCESS 200
      final p1ViewingP2 = system.getPlayerHistory(requesterId: p1.id, targetPlayerTagOrId: p2.playerId);
      expect(p1ViewingP2['statusCode'], equals(200));
      expect(p1ViewingP2['success'], isTrue);
      final p2History = p1ViewingP2['history'] as List<FriendCompletedQuestSummary>;
      expect(p2History.length, equals(1));
      expect(p2History.first.title, equals('Citadel Secrets Quest'));

      // QST-1409 views QST-2794's history -> SUCCESS 200 (Bidirectional)
      final p2ViewingP1 = system.getPlayerHistory(requesterId: p2.id, targetPlayerTagOrId: p1.playerId);
      expect(p2ViewingP1['statusCode'], equals(200));
      expect(p2ViewingP1['success'], isTrue);
      final p1History = p2ViewingP1['history'] as List<FriendCompletedQuestSummary>;
      expect(p1History.length, equals(1));
      expect(p1History.first.title, equals('Whispering Forest Sprint'));
    });

    test('7. 3rd party non-friend (QST-8888) is STRICTLY BLOCKED from viewing either player', () {
      final req = system.sendFriendRequest(senderId: p1.id, targetTag: p2.playerId);
      system.acceptFriendRequest(req.id, p2.id);

      // QST-8888 tries to view QST-2794 -> BLOCKED 403
      final p3ViewingP1 = system.getPlayerHistory(requesterId: p3.id, targetPlayerTagOrId: p1.playerId);
      expect(p3ViewingP1['statusCode'], equals(403));
      expect(p3ViewingP1['success'], isFalse);
      expect(p3ViewingP1['error'], equals('Players are not friends'));

      // QST-8888 tries to view QST-1409 -> BLOCKED 403
      final p3ViewingP2 = system.getPlayerHistory(requesterId: p3.id, targetPlayerTagOrId: p2.playerId);
      expect(p3ViewingP2['statusCode'], equals(403));
      expect(p3ViewingP2['success'], isFalse);
      expect(p3ViewingP2['error'], equals('Players are not friends'));
    });

    test('8. Own history bypass allows a player to always view their own history', () {
      final p1Own = system.getPlayerHistory(requesterId: p1.id, targetPlayerTagOrId: p1.playerId);
      expect(p1Own['statusCode'], equals(200));
      expect(p1Own['is_own_history'], isTrue);
      expect(p1Own['is_friend'], isTrue);
    });
  });
}
