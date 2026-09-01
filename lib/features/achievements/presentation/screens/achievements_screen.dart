import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/empty_state_widget.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:quest_up/features/achievements/presentation/widgets/achievement_badge_card.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements & Badges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(achievementsNotifierProvider.notifier).loadAchievements(),
          ),
        ],
      ),
      body: achievementsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerBox(width: double.infinity, height: 100, borderRadius: 20),
            ),
            SizedBox(height: 16),
            QuestCardShimmer(),
            QuestCardShimmer(),
          ],
        ),
        error: (err, _) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.read(achievementsNotifierProvider.notifier).loadAchievements(),
        ),
        data: (achievements) {
          final unlockedCount = achievements.where((a) => a.isUnlocked).length;
          final totalCount = achievements.length;
          final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

          if (achievements.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Achievements Found',
              description: 'Achievements will appear here as you embark on quests.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Progress Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E1A33),
                        AppColors.surface,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentXp.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.accentXp.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.military_tech, color: AppColors.accentXp, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trophy Vault', style: AppTypography.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              '$unlockedCount of $totalCount Badges Unlocked',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.secondary),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: AppColors.surfaceLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('All Master Badges', style: AppTypography.titleMedium),
                ),

                ...achievements.map((achievement) => AchievementBadgeCard(achievement: achievement)),
              ],
            ),
          );
        },
      ),
    );
  }
}
