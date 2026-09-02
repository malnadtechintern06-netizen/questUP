enum NotificationType {
  quest,
  leaderboard,
  achievement,
  system,
  streak,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? routeTarget;
  final String? actionLabel;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.routeTarget,
    this.actionLabel,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    String? routeTarget,
    String? actionLabel,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      routeTarget: routeTarget ?? this.routeTarget,
      actionLabel: actionLabel ?? this.actionLabel,
    );
  }
}
