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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Trophy Vault',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Vault',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
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
              child: ShimmerBox(width: double.infinity, height: 120, borderRadius: 22),
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

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(achievementsNotifierProvider.notifier).loadAchievements(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3D Summary Trophy Vault Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderBright, width: 1.2),
                      gradient: const RadialGradient(
                        center: Alignment(-0.6, -0.6),
                        radius: 1.2,
                        colors: [
                          Color(0xFF271C40),
                          Color(0xFF0F1523),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: AppColors.accentPurple.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary.withValues(alpha: 0.15),
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.6), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.military_tech_rounded, color: AppColors.secondary, size: 36),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Explorer Hall of Badges',
                                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$unlockedCount of $totalCount Trophies Unlocked',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '🔥 $hardcoreUnlocked / ${hardcoreBadges.length} Hardcore Trials Mastered',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.accentDanger,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceElevated,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Category Filter Tabs (3D Pill Tabs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        _buildFilterTab(0, 'All ($totalCount)'),
                        const SizedBox(width: 8),
                        _buildFilterTab(1, 'Hardcore (${hardcoreBadges.length})'),
                        const SizedBox(width: 8),
                        _buildFilterTab(2, 'Standard (${standardBadges.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Badges List
                  ...displayedBadges.map((badge) => AchievementBadgeCard(achievement: badge)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
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
}
