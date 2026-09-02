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
      case 'badge_globe_conqueror':
        return Icons.public_rounded;
      case 'badge_dragon_gold':
        return Icons.monetization_on_rounded;
      case 'badge_iron_legs':
        return Icons.directions_run_rounded;
      case 'badge_eagle_eye':
        return Icons.camera_alt_rounded;
      case 'badge_enigma':
        return Icons.psychology_rounded;
      case 'badge_apex_titan':
        return Icons.local_fire_department_rounded;
      case 'badge_immortal_mythic':
        return Icons.emoji_events_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'MYTHIC':
        return const Color(0xFFA855F7); // Amethyst Purple
      case 'HARDCORE':
        return const Color(0xFFEF4444); // Crimson Flame
      case 'MASTER':
        return const Color(0xFFF59E0B); // Amber Gold
      case 'ADEPT':
        return const Color(0xFF06B6D4); // Cyan Blue
      default:
        return AppColors.secondary; // Emerald
    }
  }

  String _getRequirementString() {
    final parts = <String>[];
    if (achievement.requiredLevel > 1) {
      parts.add('Level ${achievement.requiredLevel}');
    }
    if (achievement.requiredQuestCount > 0) {
      parts.add('${achievement.requiredQuestCount} Quests');
    }
    if (achievement.requiredCoins > 0) {
      parts.add('${achievement.requiredCoins} Coins');
    }
    return parts.isEmpty ? 'Unlocked on Start' : 'Requires ${parts.join(' & ')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final icon = _getIcon(achievement.iconKey);
    final tierColor = _getTierColor(achievement.tier);
    final accentColor = isUnlocked ? tierColor : AppColors.textMuted;
    final isHardcore = achievement.isHardcore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppColors.surface
            : AppColors.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? (isHardcore ? tierColor.withValues(alpha: 0.7) : tierColor.withValues(alpha: 0.4))
              : AppColors.border,
          width: isUnlocked ? (isHardcore ? 2.0 : 1.5) : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: tierColor.withValues(alpha: isHardcore ? 0.25 : 0.12),
                  blurRadius: isHardcore ? 16 : 12,
                  spreadRadius: isHardcore ? 1 : 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Glowing Emblem Box
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? tierColor.withValues(alpha: isHardcore ? 0.22 : 0.15)
                  : AppColors.surfaceLight,
              border: Border.all(
                color: isUnlocked ? tierColor : AppColors.border,
                width: isHardcore && isUnlocked ? 2.0 : 1.5,
              ),
              boxShadow: isUnlocked && isHardcore
                  ? [
                      BoxShadow(
                        color: tierColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isUnlocked ? icon : Icons.lock_outline_rounded,
              color: accentColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),

          // Details Column
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
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Tier Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: isUnlocked ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: tierColor.withValues(alpha: isUnlocked ? 0.6 : 0.25),
                        ),
                      ),
                      child: Text(
                        achievement.tier,
                        style: AppTypography.caption.copyWith(
                          color: isUnlocked ? tierColor : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Description
                Text(
                  achievement.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isUnlocked ? AppColors.textSecondary : AppColors.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Footer Status / Requirement Tag
                Row(
                  children: [
                    Icon(
                      isUnlocked ? Icons.verified_rounded : Icons.lock_clock_rounded,
                      size: 13,
                      color: isUnlocked ? AppColors.accentSuccess : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isUnlocked
                            ? 'Unlocked Trophy'
                            : _getRequirementString(),
                        style: AppTypography.caption.copyWith(
                          color: isUnlocked ? AppColors.accentSuccess : AppColors.textMuted,
                          fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
