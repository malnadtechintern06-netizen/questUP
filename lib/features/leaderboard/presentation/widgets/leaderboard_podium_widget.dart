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

    final boxDecoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderBright, width: 1.0),
      gradient: const RadialGradient(
        center: Alignment(0, -0.6),
        radius: 1.2,
        colors: [
          Color(0xFF221A3D),
          Color(0xFF0F1523),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );

    // Single champion case (e.g. user alone in Friends tab)
    if (topThree.length == 1) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        decoration: boxDecoration,
        child: Center(
          child: SizedBox(
            width: 130,
            child: _buildPodiumStep(
              entry: topThree[0],
              rankColor: AppColors.secondary,
              crownIcon: Icons.workspace_premium_rounded,
              height: 80,
              badgeText: '1ST 👑',
              isWinner: true,
              glowColor: AppColors.secondary,
            ),
          ),
        ),
      );
    }

    // Two champions case (e.g. user and 1 friend)
    if (topThree.length == 2) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
        decoration: boxDecoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildPodiumStep(
                entry: topThree[0],
                rankColor: AppColors.secondary,
                crownIcon: Icons.workspace_premium_rounded,
                height: 85,
                badgeText: '1ST 👑',
                isWinner: true,
                glowColor: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPodiumStep(
                entry: topThree[1],
                rankColor: const Color(0xFFE2E8F0),
                crownIcon: Icons.military_tech_rounded,
                height: 65,
                badgeText: '2ND',
                glowColor: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
      decoration: boxDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Silver Podium)
          Expanded(
            child: _buildPodiumStep(
              entry: second,
              rankColor: const Color(0xFFE2E8F0),
              crownIcon: Icons.military_tech_rounded,
              height: 65,
              badgeText: '2ND',
              glowColor: const Color(0xFF94A3B8),
            ),
          ),

          // 1st Place (Gold Champion Podium)
          Expanded(
            child: _buildPodiumStep(
              entry: first,
              rankColor: AppColors.secondary,
              crownIcon: Icons.workspace_premium_rounded,
              height: 85,
              badgeText: '1ST 👑',
              isWinner: true,
              glowColor: AppColors.secondary,
            ),
          ),

          // 3rd Place (Bronze Podium)
          Expanded(
            child: _buildPodiumStep(
              entry: third,
              rankColor: const Color(0xFFF97316),
              crownIcon: Icons.shield_rounded,
              height: 52,
              badgeText: '3RD',
              glowColor: const Color(0xFFEA580C),
            ),
          ),
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
          size: isWinner ? 22 : 16,
          shadows: [
            Shadow(
              color: glowColor.withValues(alpha: 0.8),
              blurRadius: isWinner ? 8 : 4,
            ),
          ],
        ),
        const SizedBox(height: 2),

        // 3D Avatar Capsule
        Container(
          width: isWinner ? 48 : 38,
          height: isWinner ? 48 : 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor.withValues(alpha: 0.25),
            border: Border.all(color: rankColor, width: isWinner ? 2.0 : 1.4),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: isWinner ? 0.35 : 0.2),
                blurRadius: isWinner ? 12 : 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(avatarIcon, color: avatarColor, size: isWinner ? 24 : 18),
        ),
        const SizedBox(height: 4),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.userName,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              if (entry.playerTag != null && entry.playerTag!.isNotEmpty)
                Text(
                  '#${entry.playerTag}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (entry.isCurrentUser) ...[
                const SizedBox(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.xp} XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.accentXp,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),

        // 3D Podium Block
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: rankColor.withValues(alpha: 0.4), width: 1.0),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                rankColor.withValues(alpha: isWinner ? 0.3 : 0.15),
                AppColors.surfaceElevated,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              badgeText,
              style: AppTypography.titleMedium.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w900,
                fontSize: isWinner ? 12 : 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
