import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/empty_state_widget.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/leaderboard/presentation/providers/leaderboard_providers.dart';
import 'package:quest_up/features/leaderboard/presentation/widgets/leaderboard_podium_widget.dart';
import 'package:quest_up/features/leaderboard/presentation/widgets/leaderboard_row_widget.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(leaderboardEntriesProvider);
    final currentFilter = ref.watch(leaderboardFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Champions Hall'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(leaderboardEntriesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterTab(ref, 'All-Time Global', 'all_time', currentFilter == 'all_time'),
                const SizedBox(width: 8),
                _buildFilterTab(ref, 'Weekly League', 'weekly', currentFilter == 'weekly'),
                const SizedBox(width: 8),
                _buildFilterTab(ref, 'Friends', 'friends', currentFilter == 'friends'),
              ],
            ),
          ),

          // Content
          Expanded(
            child: entriesAsync.when(
              loading: () => ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ShimmerBox(width: double.infinity, height: 200, borderRadius: 24),
                  ),
                  QuestCardShimmer(),
                  QuestCardShimmer(),
                ],
              ),
              error: (err, _) => ErrorStateWidget(
                message: err.toString(),
                onRetry: () => ref.refresh(leaderboardEntriesProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'No Rankings Available',
                    description: 'Leaderboards will populate as players complete quests.',
                  );
                }

                final topThree = entries.take(3).toList();
                final rest = entries.skip(3).toList();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // Top 3 Podium
                    LeaderboardPodiumWidget(topThree: topThree),
                    const SizedBox(height: 8),

                    // Section Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Full Rankings',
                        style: AppTypography.titleMedium,
                      ),
                    ),

                    // Rest of Leaderboard
                    ...rest.map((entry) => LeaderboardRowWidget(entry: entry)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(WidgetRef ref, String label, String value, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(leaderboardFilterProvider.notifier).state = value;
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.secondary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
