import '../../domain/entities/quest_calendar_entry.dart';

class QuestCalendarEntryModel extends QuestCalendarEntry {
  const QuestCalendarEntryModel({
    required super.id,
    required super.questId,
    required super.questTitle,
    required super.category,
    super.difficulty = 'Medium',
    required super.status,
    required super.timestamp,
    super.xpReward = 0,
    super.coinReward = 0,
    super.failureReason,
    super.verificationType,
  });

  factory QuestCalendarEntryModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'incomplete';
    return QuestCalendarEntryModel(
      id: json['id'] as String,
      questId: json['questId'] as String,
      questTitle: json['questTitle'] as String? ?? 'Quest Mission',
      category: json['category'] as String? ?? 'General',
      difficulty: json['difficulty'] as String? ?? 'Medium',
      status: QuestActivityStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => QuestActivityStatus.incomplete,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      xpReward: json['xpReward'] as int? ?? 0,
      coinReward: json['coinReward'] as int? ?? 0,
      failureReason: json['failureReason'] as String?,
      verificationType: json['verificationType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': questId,
      'questTitle': questTitle,
      'category': category,
      'difficulty': difficulty,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'xpReward': xpReward,
      'coinReward': coinReward,
      'failureReason': failureReason,
      'verificationType': verificationType,
    };
  }

  factory QuestCalendarEntryModel.fromEntity(QuestCalendarEntry entity) {
    return QuestCalendarEntryModel(
      id: entity.id,
      questId: entity.questId,
      questTitle: entity.questTitle,
      category: entity.category,
      difficulty: entity.difficulty,
      status: entity.status,
      timestamp: entity.timestamp,
      xpReward: entity.xpReward,
      coinReward: entity.coinReward,
      failureReason: entity.failureReason,
      verificationType: entity.verificationType,
    );
  }
}
