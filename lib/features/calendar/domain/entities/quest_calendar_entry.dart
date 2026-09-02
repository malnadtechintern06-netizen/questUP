enum QuestActivityStatus {
  completed,
  incomplete,
  failed,
}

class QuestCalendarEntry {
  final String id;
  final String questId;
  final String questTitle;
  final String category;
  final String difficulty;
  final QuestActivityStatus status;
  final DateTime timestamp;
  final int xpReward;
  final int coinReward;
  final String? failureReason;
  final String? verificationType;

  const QuestCalendarEntry({
    required this.id,
    required this.questId,
    required this.questTitle,
    required this.category,
    this.difficulty = 'Medium',
    required this.status,
    required this.timestamp,
    this.xpReward = 0,
    this.coinReward = 0,
    this.failureReason,
    this.verificationType,
  });

  bool get isCompleted => status == QuestActivityStatus.completed;
  bool get isFailed => status == QuestActivityStatus.failed;
  bool get isIncomplete => status == QuestActivityStatus.incomplete;

  QuestCalendarEntry copyWith({
    String? id,
    String? questId,
    String? questTitle,
    String? category,
    String? difficulty,
    QuestActivityStatus? status,
    DateTime? timestamp,
    int? xpReward,
    int? coinReward,
    String? failureReason,
    String? verificationType,
  }) {
    return QuestCalendarEntry(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      questTitle: questTitle ?? this.questTitle,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      failureReason: failureReason ?? this.failureReason,
      verificationType: verificationType ?? this.verificationType,
    );
  }
}
