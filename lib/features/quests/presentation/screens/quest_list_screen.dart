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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Quest Log',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Quest Activity Calendar',
            icon: const Icon(Icons.calendar_month_rounded, color: AppColors.secondary),
            onPressed: () => context.push(RoutePaths.calendar),
          ),
          IconButton(
            tooltip: 'Refresh Quests',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () =>
                ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests(),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.satellite_alt_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS: ${activeGps.latitude.toStringAsFixed(4)}, ${activeGps.longitude.toStringAsFixed(4)}',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(maxRadius / 1000).toStringAsFixed(0)}km Scan',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
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
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                        onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Category Chips
          CategoryFilterChips(
            selectedCategory: selectedCategory,
            onSelected: (cat) => ref.read(selectedCategoryProvider.notifier).state = cat,
          ),
          const SizedBox(height: 8),

          // Status segmented buttons (3D Pill Tabs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusTab(
                  ref,
                  label: 'All Quests',
                  value: 'all',
                  isSelected: statusFilter == 'all',
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  ref,
                  label: 'Available',
                  value: 'available',
                  isSelected: statusFilter == 'available',
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
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
              color: AppColors.primary,
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
                          final matchesStatus = statusFilter == 'completed'
                              ? q.isCompleted
                              : !q.isCompleted;
                          return matchesCat && matchesQuery && matchesStatus;
                        }).toList();



                        if (filtered.isEmpty) {
                          return ListView(
                            children: [
                              const SizedBox(height: 60),
                              EmptyStateWidget(
                                title: 'No Quests Found',
                                description:
                                    'No quests matching your filters. Try resetting search or moving to another location.',
                                actionText: 'Reset Filters',
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
                          padding: const EdgeInsets.only(bottom: 32),
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
    WidgetRef ref, {
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(statusFilterProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

