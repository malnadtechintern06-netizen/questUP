import 'validator_result.dart';

enum QuestAttemptStatus {
  active,
  completed,
  failed,
}

class QuestAttempt {
  final String attemptId;
  final String userId;
  final String questId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final QuestAttemptStatus status;
  final String? freshPhotoToken;
  final String? capturedPhotoPath;
  final String? capturedVideoPath;
  final List<ValidatorResult> validatorResults;

  const QuestAttempt({
    required this.attemptId,
    required this.userId,
    required this.questId,
    required this.startedAt,
    this.completedAt,
    this.status = QuestAttemptStatus.active,
    this.freshPhotoToken,
    this.capturedPhotoPath,
    this.capturedVideoPath,
    this.validatorResults = const [],
  });

  QuestAttempt copyWith({
    String? attemptId,
    String? userId,
    String? questId,
    DateTime? startedAt,
    DateTime? completedAt,
    QuestAttemptStatus? status,
    String? freshPhotoToken,
    String? capturedPhotoPath,
    String? capturedVideoPath,
    List<ValidatorResult>? validatorResults,
  }) {
    return QuestAttempt(
      attemptId: attemptId ?? this.attemptId,
      userId: userId ?? this.userId,
      questId: questId ?? this.questId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      freshPhotoToken: freshPhotoToken ?? this.freshPhotoToken,
      capturedPhotoPath: capturedPhotoPath ?? this.capturedPhotoPath,
      capturedVideoPath: capturedVideoPath ?? this.capturedVideoPath,
      validatorResults: validatorResults ?? this.validatorResults,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attemptId': attemptId,
      'userId': userId,
      'questId': questId,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status.name,
      'freshPhotoToken': freshPhotoToken,
      'capturedPhotoPath': capturedPhotoPath,
      'capturedVideoPath': capturedVideoPath,
      'validatorResults': validatorResults.map((v) => v.toJson()).toList(),
    };
  }

  factory QuestAttempt.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'active';
    return QuestAttempt(
      attemptId: json['attemptId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      questId: json['questId'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
      status: QuestAttemptStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => QuestAttemptStatus.active,
      ),
      freshPhotoToken: json['freshPhotoToken'] as String?,
      capturedPhotoPath: json['capturedPhotoPath'] as String?,
      capturedVideoPath: json['capturedVideoPath'] as String?,
      validatorResults: (json['validatorResults'] as List<dynamic>?)
              ?.map((e) => ValidatorResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
