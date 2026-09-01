import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'custom_button.dart';

class RewardDialog extends StatelessWidget {
  final String title;
  final String questTitle;
  final int xpEarned;
  final int coinsEarned;
  final bool didLevelUp;
  final int newLevel;
  final String? unlockedBadgeTitle;
  final VoidCallback onClaim;

  const RewardDialog({
    super.key,
    required this.title,
    required this.questTitle,
    required this.xpEarned,
    required this.coinsEarned,
    this.didLevelUp = false,
    this.newLevel = 1,
    this.unlockedBadgeTitle,
    required this.onClaim,
  });

  static Future<void> show(
    BuildContext context, {
    required String questTitle,
    required int xpEarned,
    required int coinsEarned,
    bool didLevelUp = false,
    int newLevel = 1,
    String? unlockedBadgeTitle,
    required VoidCallback onClaim,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RewardDialog(
        title: didLevelUp ? '🎉 LEVEL UP!' : '🏆 QUEST COMPLETED!',
        questTitle: questTitle,
        xpEarned: xpEarned,
        coinsEarned: coinsEarned,
        didLevelUp: didLevelUp,
        newLevel: newLevel,
        unlockedBadgeTitle: unlockedBadgeTitle,
        onClaim: () {
          Navigator.of(context).pop();
          onClaim();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: didLevelUp ? AppColors.secondary : AppColors.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (didLevelUp ? AppColors.secondary : AppColors.primary)
                  .withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (didLevelUp ? AppColors.secondary : AppColors.primary)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  didLevelUp ? Icons.military_tech : Icons.verified_rounded,
                  size: 56,
                  color: didLevelUp ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: didLevelUp ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                questTitle,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (didLevelUp) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentXp.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentXp, width: 1),
                  ),
                  child: Text(
                    '🌟 You have advanced to Level $newLevel!',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildRewardTile(
                      icon: Icons.bolt_rounded,
                      color: AppColors.accentXp,
                      value: '+$xpEarned',
                      label: 'XP',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRewardTile(
                      icon: Icons.monetization_on_rounded,
                      color: AppColors.secondary,
                      value: '+$coinsEarned',
                      label: 'Coins',
                    ),
                  ),
                ],
              ),
              if (unlockedBadgeTitle != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: AppColors.secondary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEW BADGE UNLOCKED!',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              unlockedBadgeTitle!,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'CLAIM REWARDS',
                icon: Icons.check_circle_outline,
                width: double.infinity,
                onPressed: onClaim,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.titleLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
