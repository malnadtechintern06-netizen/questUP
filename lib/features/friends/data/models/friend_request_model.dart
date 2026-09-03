import '../../domain/entities/friend_request.dart';

class FriendRequestModel extends FriendRequest {
  const FriendRequestModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    required super.senderTag,
    required super.senderAvatarKey,
    required super.senderLevel,
    required super.receiverId,
    required super.receiverTag,
    required super.status,
    required super.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Explorer',
      senderTag: json['senderTag'] as String? ?? 'QST-0000',
      senderAvatarKey: json['senderAvatarKey'] as String? ?? 'avatar_1',
      senderLevel: json['senderLevel'] as int? ?? 1,
      receiverId: json['receiverId'] as String? ?? '',
      receiverTag: json['receiverTag'] as String? ?? 'QST-0000',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderTag': senderTag,
      'senderAvatarKey': senderAvatarKey,
      'senderLevel': senderLevel,
      'receiverId': receiverId,
      'receiverTag': receiverTag,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FriendRequestModel.fromEntity(FriendRequest entity) {
    return FriendRequestModel(
      id: entity.id,
      senderId: entity.senderId,
      senderName: entity.senderName,
      senderTag: entity.senderTag,
      senderAvatarKey: entity.senderAvatarKey,
      senderLevel: entity.senderLevel,
      receiverId: entity.receiverId,
      receiverTag: entity.receiverTag,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }

  @override
  FriendRequestModel copyWith({
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
    return FriendRequestModel(
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

