enum SharedQuestStatus {
  pending,
  assisting,
  completed,
}

class SharedQuest {
  final String id;
  final String questId;
  final String questTitle;
  final String senderId;
  final String senderName;
  final String senderTag;
  final String receiverId;
  final SharedQuestStatus status;
  final DateTime createdAt;

  const SharedQuest({
    required this.id,
    required this.questId,
    required this.questTitle,
    required this.senderId,
    required this.senderName,
    required this.senderTag,
    required this.receiverId,
    this.status = SharedQuestStatus.pending,
    required this.createdAt,
  });

  factory SharedQuest.fromJson(Map<String, dynamic> json) {
    SharedQuestStatus parseStatus(String? st) {
      if (st == 'completed') return SharedQuestStatus.completed;
      if (st == 'assisting') return SharedQuestStatus.assisting;
      return SharedQuestStatus.pending;
    }

    return SharedQuest(
      id: json['id'] as String? ?? '',
      questId: json['quest_id'] as String? ?? '',
      questTitle: json['quest_title'] as String? ?? 'Quest Expedition',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Explorer',
      senderTag: json['sender_tag'] as String? ?? json['sender_resolved_tag'] as String? ?? 'QST-0000',
      receiverId: json['receiver_id'] as String? ?? '',
      status: parseStatus(json['status'] as String?),
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quest_id': questId,
    'quest_title': questTitle,
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_tag': senderTag,
    'receiver_id': receiverId,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
  };
}
