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
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        gradient: const RadialGradient(
          center: Alignment(0, -0.7),
          radius: 1.2,
          colors: [
            Color(0xFF221A3D),
            Color(0xFF0F1523),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Silver Podium)
          if (second != null)
            Expanded(
              child: _buildPodiumStep(
                entry: second,
                rankColor: const Color(0xFFE2E8F0),
                crownIcon: Icons.military_tech_rounded,
                height: 95,
                badgeText: '2ND',
                glowColor: const Color(0xFF94A3B8),
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // 1st Place (Gold Champion Podium)
          if (first != null)
            Expanded(
              child: _buildPodiumStep(
                entry: first,
                rankColor: AppColors.secondary,
                crownIcon: Icons.workspace_premium_rounded,
                height: 130,
                badgeText: '1ST 👑',
                isWinner: true,
                glowColor: AppColors.secondary,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // 3rd Place (Bronze Podium)
          if (third != null)
            Expanded(
              child: _buildPodiumStep(
                entry: third,
                rankColor: const Color(0xFFF97316),
                crownIcon: Icons.shield_rounded,
                height: 80,
                badgeText: '3RD',
                glowColor: const Color(0xFFEA580C),
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
    required Color glowColor,
    bool isWinner = false,
  }) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(entry.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(entry.avatarKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown Icon with ambient glow
        Icon(
          crownIcon,
          color: rankColor,
          size: isWinner ? 28 : 20,
          shadows: [
            Shadow(
              color: glowColor.withValues(alpha: 0.8),
              blurRadius: isWinner ? 12 : 6,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // 3D Avatar Capsule
        Container(
          width: isWinner ? 58 : 46,
          height: isWinner ? 58 : 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor.withValues(alpha: 0.25),
            border: Border.all(color: rankColor, width: isWinner ? 2.5 : 1.8),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: isWinner ? 0.45 : 0.25),
                blurRadius: isWinner ? 18 : 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(avatarIcon, color: avatarColor, size: isWinner ? 30 : 24),
        ),
        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            entry.userName,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          '${entry.xp} XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.accentXp,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),

        // 3D Podium Block
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: rankColor.withValues(alpha: 0.5), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                rankColor.withValues(alpha: isWinner ? 0.35 : 0.2),
                AppColors.surfaceElevated,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (isWinner)
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Center(
            child: Text(
              badgeText,
              style: AppTypography.titleMedium.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w900,
                fontSize: isWinner ? 14 : 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

