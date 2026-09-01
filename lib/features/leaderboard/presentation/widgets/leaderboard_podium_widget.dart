import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';

class LeaderboardPodiumWidget extends StatelessWidget {
  final List<LeaderboardEntry> topThree;

  const LeaderboardPodiumWidget({
    super.key,
    required this.topThree,
  });

  @override
  Widget build(BuildContext context) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            Color(0xFF231E3D),
            AppColors.surface,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Silver)
          if (second != null)
            Expanded(
              child: _buildPodiumStep(
                entry: second,
                rankColor: const Color(0xFFC0C0C0),
                crownIcon: Icons.military_tech_rounded,
                height: 90,
                badgeText: '2ND',
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // 1st Place (Gold)
          if (first != null)
            Expanded(
              child: _buildPodiumStep(
                entry: first,
                rankColor: AppColors.secondary,
                crownIcon: Icons.workspace_premium_rounded,
                height: 120,
                badgeText: '1ST',
                isWinner: true,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // 3rd Place (Bronze)
          if (third != null)
            Expanded(
              child: _buildPodiumStep(
                entry: third,
                rankColor: const Color(0xFFCD7F32),
                crownIcon: Icons.shield_rounded,
                height: 75,
                badgeText: '3RD',
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumStep({
    required LeaderboardEntry entry,
    required Color rankColor,
    required IconData crownIcon,
    required double height,
    required String badgeText,
    bool isWinner = false,
  }) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(entry.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(entry.avatarKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(crownIcon, color: rankColor, size: isWinner ? 24 : 18),
        const SizedBox(height: 4),
        Container(
          width: isWinner ? 54 : 44,
          height: isWinner ? 54 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor.withValues(alpha: 0.2),
            border: Border.all(color: rankColor, width: isWinner ? 2.0 : 1.5),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(avatarIcon, color: avatarColor, size: isWinner ? 28 : 22),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            entry.userName,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        Text(
          '${entry.xp} XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.accentXp,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: rankColor.withValues(alpha: 0.4)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                rankColor.withValues(alpha: 0.25),
                AppColors.surfaceElevated,
              ],
            ),
          ),
          child: Center(
            child: Text(
              badgeText,
              style: AppTypography.titleMedium.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
