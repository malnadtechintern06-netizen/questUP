import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'premium_3d_button.dart';

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
        title: didLevelUp ? '🎉 LEVEL UP ACHIEVED!' : '🏆 MISSION VERIFIED!',
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
    final themeColor = didLevelUp ? AppColors.secondary : AppColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: themeColor.withValues(alpha: 0.6), width: 1.8),
          gradient: const RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.1,
            colors: [
              Color(0xFF1B283E),
              Color(0xFF0F1523),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: themeColor.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D Glowing Trophy / Level Emblem
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: didLevelUp
                        ? [
                            const Color(0xFFFFE082),
                            AppColors.secondary,
                            const Color(0xFFD97706),
                          ]
                        : [
                            const Color(0xFF80F3FF),
                            AppColors.primary,
                            const Color(0xFF0096C7),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.6),
                      blurRadius: 26,
                      spreadRadius: 3,
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: Center(
                  child: Icon(
                    didLevelUp ? Icons.military_tech_rounded : Icons.workspace_premium_rounded,
                    size: 50,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: themeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                questTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),

              // Level Up Banner
              if (didLevelUp) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF00E5FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPurple.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: Colors.black),
                      const SizedBox(width: 6),
                      Text(
                        'ADVANCED TO LEVEL $newLevel!',
                        style: AppTypography.badge.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Rewards Capsules
              Row(
                children: [
                  Expanded(
                    child: _buildRewardCapsule(
                      icon: Icons.bolt_rounded,
                      color: AppColors.accentXp,
                      value: '+$xpEarned XP',
                      label: 'EXPERIENCE',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRewardCapsule(
                      icon: Icons.monetization_on_rounded,
                      color: AppColors.secondary,
                      value: '+$coinsEarned Coins',
                      label: 'GOLD BOUNTY',
                    ),
                  ),
                ],
              ),

              // Unlocked Badge Card
              if (unlockedBadgeTitle != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: AppColors.secondary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEW TROPHY UNLOCKED!',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.secondary,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              unlockedBadgeTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
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

              // 3D Claim Button
              Premium3DButton(
                text: 'CLAIM REWARDS & CONTINUE',
                icon: Icons.check_circle_rounded,
                color: themeColor,
                width: double.infinity,
                onPressed: onClaim,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCapsule({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
