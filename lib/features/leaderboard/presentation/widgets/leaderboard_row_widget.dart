import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';

class LeaderboardRowWidget extends StatelessWidget {
  final LeaderboardEntry entry;

  const LeaderboardRowWidget({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(entry.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(entry.avatarKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isCurrentUser ? AppColors.primary : AppColors.border,
          width: entry.isCurrentUser ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: AppTypography.caption.copyWith(
                  color: entry.isCurrentUser ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withValues(alpha: 0.15),
            ),
            child: Icon(avatarIcon, color: avatarColor, size: 18),
          ),
          const SizedBox(width: 8),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: AppTypography.caption.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'LVL ${entry.level} • ${entry.completedQuestsCount} Quests${entry.playerTag != null && entry.playerTag!.isNotEmpty ? " • #${entry.playerTag}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // XP Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.xp}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.accentXp,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'XP',
                style: AppTypography.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
