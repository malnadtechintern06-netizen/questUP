import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/router/app_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

final notificationFilterProvider = StateProvider.autoDispose<String>((ref) => 'all'); // 'all', 'unread'

class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsSheet(),
    );
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.quest:
        return Icons.explore_rounded;
      case NotificationType.leaderboard:
        return Icons.emoji_events_rounded;
      case NotificationType.achievement:
        return Icons.military_tech_rounded;
      case NotificationType.streak:
        return Icons.local_fire_department_rounded;
      case NotificationType.system:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.quest:
        return AppColors.accentLocation;
      case NotificationType.leaderboard:
        return AppColors.secondary;
      case NotificationType.achievement:
        return AppColors.accentXp;
      case NotificationType.streak:
        return AppColors.accentDanger;
      case NotificationType.system:
        return AppColors.primary;
    }
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '${mins <= 0 ? 1 : mins}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsNotifierProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final currentFilter = ref.watch(notificationFilterProvider);
    final screenHeight = MediaQuery.sizeOf(context).height;

    final filteredList = currentFilter == 'unread'
        ? notifications.where((n) => !n.isRead).toList()
        : notifications;

    return Container(
      height: screenHeight * 0.78,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header Bar (Overflow-proof with Flexible & compact actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Notifications',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentDanger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount New',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Manual Quest Sync button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.sync_rounded, size: 20, color: AppColors.primary),
                  tooltip: 'Check for New Quests',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checking server for newly uploaded quests...'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    await ref.read(questsNotifierProvider.notifier).refreshQuests(showLoading: false);
                  },
                ),
                if (notifications.isNotEmpty && unreadCount > 0)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      ref.read(notificationsNotifierProvider.notifier).markAllAsRead();
                    },
                    child: Text(
                      'Mark all read',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (notifications.isNotEmpty && unreadCount == 0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.clear_all_rounded, size: 20, color: AppColors.textMuted),
                    tooltip: 'Clear All',
                    onPressed: () {
                      ref.read(notificationsNotifierProvider.notifier).clearAll();
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Filter Segmented Buttons (All / Unread) - Scrollable to prevent horizontal overflow
          if (notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        context: context,
                        ref: ref,
                        label: 'All (${notifications.length})',
                        value: 'all',
                        isSelected: currentFilter == 'all',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context: context,
                        ref: ref,
                        label: 'Unread ($unreadCount)',
                        value: 'unread',
                        isSelected: currentFilter == 'unread',
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Divider(color: AppColors.border, height: 16),

          // Notification List or Clear Empty State
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState(context, isFilterUnread: currentFilter == 'unread')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final typeColor = _getTypeColor(item.type);
                      final typeIcon = _getTypeIcon(item.type);

                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.accentDanger.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.accentDanger,
                          ),
                        ),
                        onDismissed: (_) {
                          ref
                              .read(notificationsNotifierProvider.notifier)
                              .removeNotification(item.id);
                        },
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            ref
                                .read(notificationsNotifierProvider.notifier)
                                .markAsRead(item.id);
                            if (item.routeTarget != null) {
                              final target = item.routeTarget!;
                              Navigator.of(context).pop();
                              if (target.startsWith('/quests/') && target != '/quests') {
                                appRouter.push(target);
                              } else {
                                appRouter.go(target);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? AppColors.surface
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: item.isRead
                                    ? AppColors.border
                                    : AppColors.primary.withValues(alpha: 0.45),
                                width: item.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type Icon with glow
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: typeColor.withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    typeIcon,
                                    size: 20,
                                    color: typeColor,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Title & Message
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: AppTypography.titleMedium.copyWith(
                                                fontWeight: item.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.bold,
                                                color: AppColors.textPrimary,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatTimestamp(item.timestamp),
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.message,
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.actionLabel != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.actionLabel!,
                                                style: AppTypography.caption.copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 12,
                                              color: AppColors.primary,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Unread Dot
                                if (!item.isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentDanger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => ref.read(notificationFilterProvider.notifier).state = value,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isFilterUnread}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                isFilterUnread
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_off_outlined,
                size: 52,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isFilterUnread ? 'No Unread Notifications' : 'No Notifications Yet',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFilterUnread
                  ? 'All notifications have been read. Switch back to "All" to view your notification history.'
                  : 'You have no notifications right now. As you discover real-world quests, level up, and climb rankings, updates will arrive here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.explore_rounded, color: AppColors.primary, size: 18),
              label: Text(
                'DISCOVER QUESTS',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                appRouter.go(RoutePaths.quests);
              },
            ),
          ],
        ),
      ),
    );
  }
}
