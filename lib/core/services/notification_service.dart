import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quest_up/app/router/app_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String questChannelId = 'questup_new_quests_channel';
  static const String questChannelName = 'QuestUP New Quests';
  static const String questChannelDesc =
      'Real-time notifications when new quests and adventures are uploaded';

  static const AndroidNotificationChannel _questChannel =
      AndroidNotificationChannel(
    questChannelId,
    questChannelName,
    description: questChannelDesc,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Android Initialization Settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS / Darwin Initialization Settings
      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Linux Initialization Settings
      const LinuxInitializationSettings linuxSettings =
          LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create high-importance Android Notification Channel
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_questChannel);
          await androidPlugin.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
      debugPrint('[NOTIFICATIONS] NotificationService successfully initialized');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] NotificationService init notice: $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Permission request error: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('[NOTIFICATIONS] Notification tapped with payload: $payload');

    if (payload != null && payload.isNotEmpty) {
      try {
        if (payload.startsWith('/')) {
          appRouter.push(payload);
        } else {
          // It's a quest ID
          appRouter.push(RoutePaths.questDetailPath(payload));
        }
      } catch (e) {
        debugPrint('[NOTIFICATIONS] Navigation error on tap: $e');
        appRouter.go(RoutePaths.quests);
      }
    } else {
      appRouter.go(RoutePaths.quests);
    }
  }

  /// Show a system status bar notification when a new quest is uploaded
  Future<void> showNewQuestNotification(Quest quest) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final int notifId = quest.id.hashCode.abs() % 100000;
      final String rewardText =
          '+${quest.xpReward} XP • +${quest.coinReward} Coins';
      final String locationText =
          quest.locationName.isNotEmpty ? ' at ${quest.locationName}' : '';

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _questChannel.id,
        _questChannel.name,
        channelDescription: _questChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/launcher_icon',
        styleInformation: BigTextStyleInformation(
          '🗺️ New adventure available$locationText!\nRewards: $rewardText.\n${quest.description}',
          contentTitle: '⚔️ New Quest: ${quest.title}',
          summaryText: 'QuestUP Adventure Alert',
        ),
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: notifId,
        title: '⚔️ New Quest: ${quest.title}',
        body: '📍 ${quest.locationName} • $rewardText • Tap to explore!',
        notificationDetails: platformDetails,
        payload: quest.id,
      );

      debugPrint(
          '[NOTIFICATIONS] System status-bar notification dispatched for quest: ${quest.title} (ID: ${quest.id})');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Failed to show system notification: $e');
    }
  }

  /// Generic system notification for streak, leaderboard, or achievement
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _questChannel.id,
        _questChannel.name,
        channelDescription: _questChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );

      const DarwinNotificationDetails darwinDetails =
          DarwinNotificationDetails();

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error showing generic notification: $e');
    }
  }
}
