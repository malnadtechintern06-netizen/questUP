import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/empty_state_widget.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:quest_up/features/achievements/presentation/widgets/achievement_badge_card.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  int _selectedFilterIndex = 0; // 0 = All, 1 = Hardcore, 2 = Standard

  @override
  Widget build(BuildContext context) {
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

          final hardcoreBadges = achievements.where((a) => a.isHardcore).toList();
          final standardBadges = achievements.where((a) => !a.isHardcore).toList();
          final hardcoreUnlocked = hardcoreBadges.where((a) => a.isUnlocked).length;

          if (achievements.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Achievements Found',
              description: 'Achievements will appear here as you embark on quests.',
            );
          }

          final displayedBadges = _selectedFilterIndex == 1
              ? hardcoreBadges
              : (_selectedFilterIndex == 2 ? standardBadges : achievements);

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
                        Color(0xFF231B38),
                        Color(0xFF141221),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentXp.withValues(alpha: 0.18),
                              border: Border.all(color: AppColors.accentXp.withValues(alpha: 0.5)),
                            ),
                            child: const Icon(Icons.military_tech_rounded, color: AppColors.accentXp, size: 36),
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
                                const SizedBox(height: 2),
                                Text(
                                  '🔥 $hardcoreUnlocked / ${hardcoreBadges.length} Hardcore Trials Mastered',
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFFF97316),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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

                // Category Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildFilterTab(0, 'All ($totalCount)'),
                      const SizedBox(width: 8),
                      _buildFilterTab(1, '🔥 Hardcore (${hardcoreBadges.length})'),
                      const SizedBox(width: 8),
                      _buildFilterTab(2, '🛡️ Standard (${standardBadges.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Section Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedFilterIndex == 1
                            ? 'Hardcore & Mythic Trials'
                            : (_selectedFilterIndex == 2
                                ? 'Pioneer Badges'
                                : 'All Available Badges'),
                        style: AppTypography.titleMedium,
                      ),
                      Text(
                        '${displayedBadges.where((b) => b.isUnlocked).length} / ${displayedBadges.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badges List
                ...displayedBadges.map((achievement) => AchievementBadgeCard(achievement: achievement)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilterIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (index == 1
                    ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                    : AppColors.primary.withValues(alpha: 0.18))
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (index == 1 ? const Color(0xFFEF4444) : AppColors.primary)
                  : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: isSelected
                  ? (index == 1 ? const Color(0xFFEF4444) : AppColors.primary)
                  : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
