import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/achievement.dart';

class AchievementBadgeCard extends StatelessWidget {
  final Achievement achievement;

  const AchievementBadgeCard({
    super.key,
    required this.achievement,
  });

  IconData _getIcon(String key) {
    switch (key) {
      case 'badge_compass':
        return Icons.explore_rounded;
      case 'badge_first_quest':
        return Icons.stars_rounded;
      case 'badge_trail':
        return Icons.hiking_rounded;
      case 'badge_coins':
        return Icons.savings_rounded;
      case 'badge_shield':
        return Icons.shield_rounded;
      case 'badge_crown':
        return Icons.military_tech_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final icon = _getIcon(achievement.iconKey);
    final accentColor = isUnlocked ? AppColors.secondary : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.surface : AppColors.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked ? AppColors.secondary.withValues(alpha: 0.4) : AppColors.border,
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? AppColors.secondary.withValues(alpha: 0.15)
                  : AppColors.surfaceLight,
              border: Border.all(
                color: isUnlocked ? AppColors.secondary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Icon(
              isUnlocked ? icon : Icons.lock_outline_rounded,
              color: accentColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: isUnlocked ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'UNLOCKED',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isUnlocked ? AppColors.textSecondary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
