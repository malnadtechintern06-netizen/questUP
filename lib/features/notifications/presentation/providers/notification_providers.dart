import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_notification.dart';

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier() : super(_initialNotifications);

  static final List<AppNotification> _initialNotifications = [
    AppNotification(
      id: 'notif-1',
      title: 'Nearby Quests Discovered!',
      message: 'New real-world landmark waypoints have been detected near your location. Start exploring!',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      type: NotificationType.quest,
      isRead: false,
      routeTarget: '/quests',
      actionLabel: 'View Quests',
    ),
    AppNotification(
      id: 'notif-2',
      title: 'Daily Streak Bonus Active 🔥',
      message: 'You are on a 3-day exploration streak. Complete today\'s creative or fitness activity to claim +50 XP bonus!',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.streak,
      isRead: false,
      routeTarget: '/quests',
      actionLabel: 'Explore Quests',
    ),
    AppNotification(
      id: 'notif-3',
      title: 'Champions League Ranking Update 🏆',
      message: 'You moved up the Weekly Explorer Leaderboard. Check your new rank against other adventurers.',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      type: NotificationType.leaderboard,
      isRead: true,
      routeTarget: '/leaderboard',
      actionLabel: 'Check Hall',
    ),
    AppNotification(
      id: 'notif-4',
      title: 'Badge Progress: Trail Explorer',
      message: 'You need just 1 more location verification to unlock the prestigious Trail Explorer badge.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.achievement,
      isRead: true,
      routeTarget: '/achievements',
      actionLabel: 'View Badges',
    ),
  ];

  void addNotification(AppNotification notification) {
    if (state.any((n) => n.id == notification.id)) return;
    state = [notification, ...state];
  }

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
  return NotificationsNotifier();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsNotifierProvider);
  return list.where((n) => !n.isRead).length;
});
