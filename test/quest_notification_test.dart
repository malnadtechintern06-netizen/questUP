import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/features/notifications/domain/entities/app_notification.dart';
import 'package:quest_up/features/notifications/presentation/providers/notification_providers.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Quest Notification System Tests', () {
    test('AppNotification entity holds quest route target and unread status correctly', () {
      final notif = AppNotification(
        id: 'notif-new-quest-api-99',
        title: '⚔️ New Quest: Whispering Woods',
        message: 'New real-world adventure available at Forest Sanctuary! Rewards: +150 XP • +80 Coins.',
        timestamp: DateTime.now(),
        type: NotificationType.quest,
        isRead: false,
        routeTarget: '/quests/api-99',
        actionLabel: 'Explore Quest',
      );

      expect(notif.id, 'notif-new-quest-api-99');
      expect(notif.isRead, false);
      expect(notif.type, NotificationType.quest);
      expect(notif.routeTarget, '/quests/api-99');
      expect(notif.actionLabel, 'Explore Quest');

      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, true);
    });

    test('NotificationsNotifier tracks unread count and marks quest notifications as read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationsNotifierProvider.notifier);

      // Add newly uploaded quest notification
      notifier.addNotification(
        AppNotification(
          id: 'notif-quest-test-101',
          title: '⚔️ New Quest: Castle Ramparts',
          message: 'Explore Castle Ramparts (+200 XP, +100 Coins)',
          timestamp: DateTime.now(),
          type: NotificationType.quest,
          isRead: false,
          routeTarget: '/quests/test-101',
          actionLabel: 'Explore Quest',
        ),
      );

      final unreadCount = container.read(unreadNotificationsCountProvider);
      expect(unreadCount, greaterThan(0));

      final list = container.read(notificationsNotifierProvider);
      expect(list.any((n) => n.id == 'notif-quest-test-101'), isTrue);

      // Mark as read
      notifier.markAsRead('notif-quest-test-101');
      final updatedList = container.read(notificationsNotifierProvider);
      final updatedItem = updatedList.firstWhere((n) => n.id == 'notif-quest-test-101');
      expect(updatedItem.isRead, isTrue);
    });
  });
}
