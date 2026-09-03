import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/presentation/providers/friends_providers.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';

class FriendDetailScreen extends ConsumerStatefulWidget {
  final String friendUserId;

  const FriendDetailScreen({
    super.key,
    required this.friendUserId,
  });

  @override
  ConsumerState<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  FriendProfile? _friend;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFriend();
  }

  Future<void> _fetchFriend() async {
    setState(() => _isLoading = true);
    final profile = await ref
        .read(friendsNotifierProvider.notifier)
        .loadFriendDetail(widget.friendUserId);
    if (mounted) {
      setState(() {
        _friend = profile;
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains('Nature')) return Icons.forest_rounded;
    if (cat.contains('Landmark')) return Icons.account_balance_rounded;
    if (cat.contains('Culture')) return Icons.palette_rounded;
    if (cat.contains('Fitness')) return Icons.directions_run_rounded;
    if (cat.contains('Mystery')) return Icons.vpn_key_rounded;
    return Icons.explore_rounded;
  }

  IconData _getBadgeIcon(String key) {
    switch (key) {
      case 'badge_immortal_mythic':
        return Icons.emoji_events_rounded;
      case 'badge_apex_titan':
        return Icons.local_fire_department_rounded;
      case 'badge_crown':
        return Icons.military_tech_rounded;
      case 'badge_iron_legs':
        return Icons.directions_run_rounded;
      case 'badge_dragon_gold':
        return Icons.monetization_on_rounded;
      case 'badge_shield':
        return Icons.shield_rounded;
      case 'badge_trail':
        return Icons.hiking_rounded;
      case 'badge_compass':
        return Icons.explore_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Color _getBadgeTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'MYTHIC':
        return AppColors.accentPurple;
      case 'HARDCORE':
        return AppColors.accentDanger;
      case 'MASTER':
        return AppColors.secondary;
      case 'ADEPT':
        return AppColors.primary;
      default:
        return AppColors.accentSuccess;
    }
  }

  void _showRemoveFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove from Squad?',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${_friend?.name ?? 'this player'} from your friends list?',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentDanger),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(friendsNotifierProvider.notifier).removeFriend(widget.friendUserId);
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text('REMOVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              ShimmerBox(width: double.infinity, height: 180, borderRadius: 24),
              SizedBox(height: 16),
              ShimmerBox(width: double.infinity, height: 100, borderRadius: 18),
              SizedBox(height: 16),
              QuestCardShimmer(),
            ],
          ),
        ),
      );
    }

    if (_friend == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: ErrorStateWidget(
          message: 'Player profile could not be loaded.',
          onRetry: _fetchFriend,
        ),
      );
    }

    final friend = _friend!;
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(friend.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(friend.avatarKey);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Friend Game Profile',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Remove Friend',
            icon: const Icon(Icons.person_remove_rounded, color: AppColors.textMuted),
            onPressed: () => _showRemoveFriendDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 3D Hero Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderBright, width: 1.2),
                gradient: const RadialGradient(
                  center: Alignment(-0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0xFF241C3E),
                    Color(0xFF0F1523),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 3D Avatar
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: avatarColor.withValues(alpha: 0.25),
                          border: Border.all(color: avatarColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: avatarColor.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(avatarIcon, color: avatarColor, size: 38),
                      ),
                      const SizedBox(width: 16),

                      // Name, Tag & Rank Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.name,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unique ID: ${friend.playerTag}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                friend.rankTitle.toUpperCase(),
                                style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Online / Activity Status Line
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          friend.isOnline ? Icons.radar_rounded : Icons.history_toggle_off_rounded,
                          size: 14,
                          color: friend.isOnline ? AppColors.accentSuccess : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          friend.lastActiveText,
                          style: AppTypography.caption.copyWith(
                            color: friend.isOnline ? AppColors.accentSuccess : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. 4 Key Game Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Quests Cleared',
                    value: '${friend.completedQuestsCount}',
                    subtitle: 'of ${friend.gamesPlayedCount} Played',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.accentSuccess,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Current Rank',
                    value: '#${friend.rank}',
                    subtitle: 'Leaderboard',
                    icon: Icons.workspace_premium_rounded,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total XP Score',
                    value: '${friend.currentXp}',
                    subtitle: 'Mastery Level ${friend.level}',
                    icon: Icons.bolt_rounded,
                    color: AppColors.accentXp,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Badges Earned',
                    value: '${friend.earnedBadges.length}',
                    subtitle: 'Trophy Vault',
                    icon: Icons.military_tech_rounded,
                    color: AppColors.accentPurple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Completed Games & Quest History Section
            _buildSectionHeader('COMPLETED GAMES & QUEST HISTORY', Icons.history_edu_rounded),
            const SizedBox(height: 10),

            if (friend.completedQuests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'No completed quests recorded yet.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              ...friend.completedQuests.map((quest) => _buildQuestHistoryCard(quest)),

            const SizedBox(height: 24),

            // 4. Earned Badges Section
            _buildSectionHeader('EARNED TROPHY BADGES', Icons.military_tech_rounded),
            const SizedBox(height: 10),

            if (friend.earnedBadges.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'No badges unlocked yet.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              ...friend.earnedBadges.map((badge) => _buildBadgeCard(badge)),

            const SizedBox(height: 24),

            // 5. Action Button
            Premium3DButton(
              text: 'CHALLENGE FRIEND ON RADAR',
              icon: Icons.sports_esports_rounded,
              color: AppColors.primary,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Radar Quest Challenge invitation sent to ${friend.name}! 🎯'),
                    backgroundColor: AppColors.surfaceElevated,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 11, letterSpacing: 1.0),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderBright, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestHistoryCard(FriendCompletedQuestSummary quest) {
    final catIcon = _getCategoryIcon(quest.category);
    final dateStr = '${quest.completedAt.day}/${quest.completedAt.month}/${quest.completedAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Icon(catIcon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        quest.locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentXp.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${quest.xpEarned} XP',
                        style: AppTypography.caption.copyWith(color: AppColors.accentXp, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${quest.coinsEarned} 🪙',
                        style: AppTypography.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
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

  Widget _buildBadgeCard(FriendBadgeSummary badge) {
    final icon = _getBadgeIcon(badge.iconKey);
    final tierColor = _getBadgeTierColor(badge.tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tierColor.withValues(alpha: 0.2),
              border: Border.all(color: tierColor, width: 1.5),
            ),
            child: Icon(icon, color: tierColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  badge.isHardcore ? 'Hardcore Trial Mastered' : 'Trophy Unlocked',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tierColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              badge.tier,
              style: AppTypography.caption.copyWith(color: tierColor, fontWeight: FontWeight.bold, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
