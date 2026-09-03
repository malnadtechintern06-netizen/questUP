enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}

class FriendRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String senderTag;
  final String senderAvatarKey;
  final int senderLevel;
  final String receiverId;
  final String receiverTag;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderTag,
    required this.senderAvatarKey,
    required this.senderLevel,
    required this.receiverId,
    required this.receiverTag,
    required this.status,
    required this.createdAt,
  });

  FriendRequest copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderTag,
    String? senderAvatarKey,
    int? senderLevel,
    String? receiverId,
    String? receiverTag,
    FriendRequestStatus? status,
    DateTime? createdAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderTag: senderTag ?? this.senderTag,
      senderAvatarKey: senderAvatarKey ?? this.senderAvatarKey,
      senderLevel: senderLevel ?? this.senderLevel,
      receiverId: receiverId ?? this.receiverId,
      receiverTag: receiverTag ?? this.receiverTag,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
