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
            onPressed: () {
              ref.invalidate(leaderboardByFilterProvider(currentFilter));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Timeframe Filter Tabs (3D Pill Tabs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildTimeframeTab(
                  ref,
                  label: 'All Time',
                  value: 'all_time',
                  isSelected: currentFilter == 'all_time',
                ),
                const SizedBox(width: 6),
                _buildTimeframeTab(
                  ref,
                  label: 'Weekly',
                  value: 'weekly',
                  isSelected: currentFilter == 'weekly',
                ),
                const SizedBox(width: 6),
                _buildTimeframeTab(
                  ref,
                  label: 'Friends',
                  value: 'friends',
                  isSelected: currentFilter == 'friends',
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Main Rankings List
          Expanded(
            child: entriesAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                children: const [
                  ShimmerBox(width: double.infinity, height: 160, borderRadius: 20),
                  SizedBox(height: 12),
                  ShimmerBox(width: double.infinity, height: 64, borderRadius: 14),
                  SizedBox(height: 10),
                  ShimmerBox(width: double.infinity, height: 64, borderRadius: 14),
                ],
              ),
              error: (err, _) => ErrorStateWidget(
                message: err.toString(),
                onRetry: () => ref.invalidate(leaderboardByFilterProvider(currentFilter)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  if (currentFilter == 'friends') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.people_alt_rounded, size: 42, color: AppColors.primary),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Friends in Your Squad',
                              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add your friends by Player ID to see who ranks #1 in your squad.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () => appRouter.push(RoutePaths.friends),
                              icon: const Icon(Icons.person_add_rounded, color: Colors.black, size: 18),
                              label: const Text(
                                'Find & Add Friends',
                                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 44, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No champions ranked yet.',
                            style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(leaderboardByFilterProvider(currentFilter)),
                            child: const Text('Refresh Rankings'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show Top 3 in 3D Podium, and remaining in ranked cards
                final topThree = entries.take(3).toList();
                final remaining = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];
                final currentUserEntry = entries.where((e) => e.isCurrentUser).firstOrNull;
                final hasNoFriends = currentFilter == 'friends' && entries.where((e) => !e.isCurrentUser).isEmpty;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(leaderboardByFilterProvider(currentFilter)),
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.only(
                          bottom: currentUserEntry != null ? 85 : 20,
                        ),
                        children: [
                          if (hasNoFriends)
                            _buildNoFriendsBanner(context),

                          // 3D Top Podium (Top 1, 2, 3)
                          if (topThree.isNotEmpty)
                            LeaderboardPodiumWidget(topThree: topThree),

                          const SizedBox(height: 6),

                          // Rank 4 to 10 List
                          ...remaining.map((entry) => _buildRankCard(entry, currentFilter)),
                        ],
                      ),

                      // Sticky Bottom Current User Card (displays user's exact ranking)
                      if (currentUserEntry != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 8,
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No Squad Friends Yet',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Add friends to compare squad rank & XP.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => appRouter.push(RoutePaths.friends),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primaryLight
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.primary
              : AppColors.border,
          width: entry.isCurrentUser ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: entry.isCurrentUser
              ? null
              : () => appRouter.push(RoutePaths.friendDetailPath(entry.userId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 28,
                  height: 28,
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
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Avatar Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor, width: 1.0),
                  ),
                  child: Icon(avatarIcon, color: avatarColor, size: 20),
                ),
                const SizedBox(width: 10),

                // Name, Tag and Level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                                fontSize: 13,
                                color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (entry.isCurrentUser) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Level ${entry.level} Explorer${entry.playerTag != null && entry.playerTag!.isNotEmpty ? " • #${entry.playerTag}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // XP Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentXp.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 12, color: AppColors.accentXp),
                      const SizedBox(width: 2),
                      Text(
                        '${entry.xp} XP',
                        style: AppTypography.gameNumber.copyWith(
                          color: AppColors.accentXp,
                          fontSize: 10,
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
    final totalServer = entry.totalParticipants ?? 152;
    String subtitleText = 'Server Rank #${entry.rank} of $totalServer • ${entry.xp} XP';

    if (filter == 'friends') {
      titleText = 'Your Squad Standing';
      final friendCount = entry.totalParticipants ?? totalCount;
      subtitleText = friendCount > 1
          ? 'Squad Rank #${entry.rank} of $friendCount • ${entry.xp} XP'
          : 'Squad Rank #${entry.rank} • ${entry.xp} XP';
    } else if (filter == 'weekly') {
      titleText = 'Your Weekly Standing';
      subtitleText = 'Weekly Rank #${entry.rank} of $totalServer • ${entry.xp} XP';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
        ],
      ),
    );
  }
}
