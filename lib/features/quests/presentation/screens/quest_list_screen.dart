import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/empty_state_widget.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/location_permission/presentation/providers/location_permission_provider.dart';
import 'package:quest_up/features/notifications/presentation/providers/notification_providers.dart';
import 'package:quest_up/features/notifications/presentation/widgets/notifications_sheet.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/quests/presentation/widgets/category_filter_chips.dart';
import 'package:quest_up/features/quests/presentation/widgets/quest_card_widget.dart';

final statusFilterProvider = StateProvider<String>((ref) => 'all'); // 'all', 'available', 'completed'

class QuestListScreen extends ConsumerWidget {
  const QuestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(questsNotifierProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final query = ref.watch(searchQueryProvider);
    final activeGps = ref.watch(activeGpsCoordinatesProvider);
    final maxRadius = ref.watch(maxRadiusFilterMetersProvider);
    final unreadNotifsCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Quests'),
        actions: [
          IconButton(
            tooltip: 'Refresh Quests',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests(),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => NotificationsSheet.show(context),
              ),
              if (unreadNotifsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.accentDanger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadNotifsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Live GPS coordinate banner
          if (activeGps != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 14, color: AppColors.accentLocation),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'GPS: Lat ${activeGps.latitude.toStringAsFixed(4)}, Lon ${activeGps.longitude.toStringAsFixed(4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(maxRadius / 1000).toStringAsFixed(0)}km radius',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search quests by title or landmark...',
                hintStyle: AppTypography.bodyMedium,
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),

          // Category Chips
          CategoryFilterChips(
            selectedCategory: selectedCategory,
            onSelected: (cat) => ref.read(selectedCategoryProvider.notifier).state = cat,
          ),
          const SizedBox(height: 6),

          // Status segmented buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusTab(
                  context,
                  ref,
                  label: 'All',
                  value: 'all',
                  isSelected: statusFilter == 'all',
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  context,
                  ref,
                  label: 'Available',
                  value: 'available',
                  isSelected: statusFilter == 'available',
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  context,
                  ref,
                  label: 'Completed',
                  value: 'completed',
                  isSelected: statusFilter == 'completed',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List of quests (Closest first)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(questsNotifierProvider.notifier)
                    .refreshLocationAndQuests();
              },
              child: activeGps == null
                  ? ListView(
                      children: [
                        const SizedBox(height: 60),
                        EmptyStateWidget(
                          icon: Icons.location_off_rounded,
                          title: 'Location Services Required',
                          description:
                              'Quests are only loaded once location services are turned on. Please enable GPS to discover quests around you.',
                          actionText: 'Enable Location',
                          onAction: () async {
                            final notifier =
                                ref.read(locationPermissionNotifierProvider.notifier);
                            final success =
                                await notifier.requestAndAcquireLocation();
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Please enable GPS and location permissions in device settings to load quests.',
                                  ),
                                  action: SnackBarAction(
                                    label: 'SETTINGS',
                                    onPressed: () => notifier.openAppSettings(),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    )
                  : questsAsync.when(
                      loading: () => ListView(
                        children: const [
                          QuestCardShimmer(),
                          QuestCardShimmer(),
                          QuestCardShimmer(),
                        ],
                      ),
                      error: (err, _) => ErrorStateWidget(
                        message: err.toString(),
                        onRetry: () => ref
                            .read(questsNotifierProvider.notifier)
                            .refreshLocationAndQuests(),
                      ),
                      data: (quests) {
                        final filtered = quests.where((q) {
                          final matchesCat =
                              selectedCategory == null || q.category == selectedCategory;
                          final matchesQuery = query.isEmpty ||
                              q.title.toLowerCase().contains(query.toLowerCase()) ||
                              q.locationName.toLowerCase().contains(query.toLowerCase());
                          final matchesStatus = statusFilter == 'all' ||
                              (statusFilter == 'completed' && q.isCompleted) ||
                              (statusFilter == 'available' && !q.isCompleted);
                          return matchesCat && matchesQuery && matchesStatus;
                        }).toList();

                        if (filtered.isEmpty) {
                          return ListView(
                            children: [
                              const SizedBox(height: 60),
                              EmptyStateWidget(
                                title: 'No Quests Nearby',
                                description:
                                    'No nearby quests found. Move to another location to discover new quests.',
                                actionText: 'Refresh Nearby Quests',
                                onAction: () {
                                  ref.read(selectedCategoryProvider.notifier).state = null;
                                  ref.read(searchQueryProvider.notifier).state = '';
                                  ref.read(statusFilterProvider.notifier).state = 'all';
                                  ref
                                      .read(questsNotifierProvider.notifier)
                                      .refreshLocationAndQuests();
                                },
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final quest = filtered[index];
                            return QuestCardWidget(
                              quest: quest,
                              onTap: () {
                                context.push(RoutePaths.questDetailPath(quest.id));
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(statusFilterProvider.notifier).state = value,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
