import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/router/app_router.dart';
import 'package:quest_up/app/router/route_paths.dart';

import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';

import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:quest_up/features/leaderboard/presentation/providers/leaderboard_providers.dart';
import 'package:quest_up/features/leaderboard/presentation/widgets/leaderboard_podium_widget.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(leaderboardEntriesProvider);
    final currentFilter = ref.watch(leaderboardFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Champions Hall',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Rankings',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ref.refresh(leaderboardEntriesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timeframe Filter Tabs (3D Pill Tabs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildTimeframeTab(
                  ref,
                  label: 'All Time',
                  value: 'all_time',
                  isSelected: currentFilter == 'all_time',
                ),
                const SizedBox(width: 8),
                _buildTimeframeTab(
                  ref,
                  label: 'Weekly',
                  value: 'weekly',
                  isSelected: currentFilter == 'weekly',
                ),
                const SizedBox(width: 8),
                _buildTimeframeTab(
                  ref,
                  label: 'Friends',
                  value: 'friends',
                  isSelected: currentFilter == 'friends',
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Main Rankings List
          Expanded(
            child: entriesAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ShimmerBox(width: double.infinity, height: 180, borderRadius: 24),
                  SizedBox(height: 16),
                  ShimmerBox(width: double.infinity, height: 72, borderRadius: 16),
                  SizedBox(height: 12),
                  ShimmerBox(width: double.infinity, height: 72, borderRadius: 16),
                ],
              ),
              error: (err, _) => ErrorStateWidget(
                message: err.toString(),
                onRetry: () => ref.refresh(leaderboardEntriesProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No champions ranked yet. Be the first!',
                      style: AppTypography.bodyMedium,
                    ),
                  );
                }

                final topThree = entries.take(3).toList();
                final remaining = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];
                final currentUserEntry = entries.where((e) => e.isCurrentUser).firstOrNull;
                final hasNoFriends = currentFilter == 'friends' && entries.where((e) => !e.isCurrentUser).isEmpty;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.refresh(leaderboardEntriesProvider),
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.only(
                          bottom: currentUserEntry != null ? 100 : 24,
                        ),
                        children: [
                          if (hasNoFriends)
                            _buildNoFriendsBanner(context),

                          // 3D Top Podium
                          if (topThree.isNotEmpty)
                            LeaderboardPodiumWidget(topThree: topThree),

                          const SizedBox(height: 10),

                          // Rank 4+ List
                          ...remaining.map((entry) => _buildRankCard(entry, currentFilter)),
                        ],
                      ),

                      // Sticky Bottom Current User Card
                      if (currentUserEntry != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 12,
                          child: _buildStickyUserCard(currentUserEntry, currentFilter, entries.length),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFriendsBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Squad Friends Yet',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add friends via Player ID to compare your rank and XP here.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => appRouter.push(RoutePaths.friends),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeTab(
    WidgetRef ref, {
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(leaderboardFilterProvider.notifier).state = value,
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

  Widget _buildRankCard(LeaderboardEntry entry, String filter) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(entry.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(entry.avatarKey);
    final xpSuffix = filter == 'weekly' ? 'XP' : 'XP';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primaryLight
            : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.primary
              : AppColors.border,
          width: entry.isCurrentUser ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: entry.isCurrentUser
              ? null
              : () => appRouter.push(RoutePaths.friendDetailPath(entry.userId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      '#${entry.rank}',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor, width: 1.2),
                  ),
                  child: Icon(avatarIcon, color: avatarColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Name and Level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (entry.isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Level ${entry.level} Explorer',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // XP Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentXp.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accentXp),
                      const SizedBox(width: 3),
                      Text(
                        '${entry.xp} $xpSuffix',
                        style: AppTypography.gameNumber.copyWith(
                          color: AppColors.accentXp,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyUserCard(LeaderboardEntry entry, String filter, int totalCount) {
    String titleText = 'Your Hall of Fame Standing';
    String subtitleText = 'Level ${entry.level} • ${entry.xp} Total XP';

    if (filter == 'friends') {
      titleText = 'Your Squad Standing';
      subtitleText = totalCount > 1
          ? 'Rank #${entry.rank} of $totalCount friends • ${entry.xp} XP'
          : 'Rank #${entry.rank} • ${entry.xp} XP';
    } else if (filter == 'weekly') {
      titleText = 'Your Weekly Standing';
      subtitleText = 'Rank #${entry.rank} • ${entry.xp} Weekly XP';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  subtitleText,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
        ],
      ),
    );
  }
}
