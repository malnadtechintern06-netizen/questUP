enum QuestSessionStatus {
  inProgress,
  submitted,
  verified,
  rejected,
  expired,
}

class QuestSession {
  final String sessionId;
  final String userId;
  final String questId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final double? startingLocationLat;
  final double? startingLocationLon;
  final QuestSessionStatus status;
  final String? requiredProofType;
  final DateTime? completedAt;

  const QuestSession({
    required this.sessionId,
    required this.userId,
    required this.questId,
    required this.startedAt,
    required this.expiresAt,
    this.startingLocationLat,
    this.startingLocationLon,
    this.status = QuestSessionStatus.inProgress,
    this.requiredProofType,
    this.completedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => status == QuestSessionStatus.inProgress && !isExpired;

  QuestSession copyWith({
    String? sessionId,
    String? userId,
    String? questId,
    DateTime? startedAt,
    DateTime? expiresAt,
    double? startingLocationLat,
    double? startingLocationLon,
    QuestSessionStatus? status,
    String? requiredProofType,
    DateTime? completedAt,
  }) {
    return QuestSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      questId: questId ?? this.questId,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      startingLocationLat: startingLocationLat ?? this.startingLocationLat,
      startingLocationLon: startingLocationLon ?? this.startingLocationLon,
      status: status ?? this.status,
      requiredProofType: requiredProofType ?? this.requiredProofType,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'questId': questId,
      'startedAt': startedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'startingLocationLat': startingLocationLat,
      'startingLocationLon': startingLocationLon,
      'status': status.name,
      'requiredProofType': requiredProofType,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory QuestSession.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'inProgress';
    final started = DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now();
    final expires = json['expiresAt'] != null
        ? DateTime.tryParse(json['expiresAt'] as String) ?? started.add(const Duration(hours: 24))
        : started.add(const Duration(hours: 24));

    return QuestSession(
      sessionId: json['sessionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      questId: json['questId'] as String? ?? '',
      startedAt: started,
      expiresAt: expires,
      startingLocationLat: (json['startingLocationLat'] as num?)?.toDouble(),
      startingLocationLon: (json['startingLocationLon'] as num?)?.toDouble(),
      status: QuestSessionStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => QuestSessionStatus.inProgress,
      ),
      requiredProofType: json['requiredProofType'] as String?,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
    );
  }
}
