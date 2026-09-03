import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router/app_router.dart';
import '../../app/router/route_paths.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/location_permission/presentation/providers/location_permission_provider.dart';
import '../../features/profile/presentation/providers/user_providers.dart';
import '../../features/profile/presentation/widgets/avatar_selector_sheet.dart';
import '../../features/quests/presentation/providers/quest_providers.dart';
import '../../features/friends/presentation/providers/friends_providers.dart';


class AppDrawer extends ConsumerWidget {
  final VoidCallback? onOpenGpsSimulator;

  const AppDrawer({
    super.key,
    this.onOpenGpsSimulator,
  });

  void _showHowToPlayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.borderBright, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'How to Play QuestUP',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideTile(
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
                title: '1. Discover Real-World Quests',
                desc: 'Enable GPS radar to detect quests at nearby monuments, parks, and landmarks.',
              ),
              const SizedBox(height: 12),
              _buildGuideTile(
                icon: Icons.qr_code_scanner_rounded,
                color: AppColors.accentXp,
                title: '2. Complete & Verify Proof',
                desc: 'Travel to waypoints within GPS radius and submit proof with live camera or physical steps.',
              ),
              const SizedBox(height: 12),
              _buildGuideTile(
                icon: Icons.emoji_events_rounded,
                color: AppColors.secondary,
                title: '3. Level Up & Claim Bounties',
                desc: 'Collect XP, coins, unlock prestigious badges, and top the weekly champions leaderboard.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'GOT IT',
              style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGuideTile({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of QuestUP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'CANCEL',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // Close only the dialog
              await ref.read(authNotifierProvider.notifier).logout();
              appRouter.go(RoutePaths.welcome);
            },
            child: Text(
              'SIGN OUT',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.accentDanger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final userProfileAsync = ref.watch(userProfileNotifierProvider);
    final activeGps = ref.watch(activeGpsCoordinatesProvider);
    final pendingRequestsCount = ref.watch(pendingFriendRequestsCountProvider);
    final profile = userProfileAsync.valueOrNull;
    final userName = (authState.user?.displayName.isNotEmpty ?? false)
        ? authState.user!.displayName
        : (profile?.name ?? 'Explorer');
    final userLevel = profile?.level ?? 1;
    final userXp = profile?.currentXp ?? 0;
    final userCoins = profile?.coins ?? 0;
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(profile?.avatarKey ?? 'avatar_1');
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(profile?.avatarKey ?? 'avatar_1');

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 1. 3D User Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(
                  bottom: BorderSide(color: AppColors.borderBright, width: 1.2),
                ),
                gradient: const RadialGradient(
                  center: Alignment(-0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0xFF1F2B42),
                    Color(0xFF0F1523),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 3D Avatar
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: avatarColor.withValues(alpha: 0.2),
                          border: Border.all(color: avatarColor, width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: avatarColor.withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(avatarIcon, color: avatarColor, size: 30),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'LVL $userLevel Explorer',
                                style: AppTypography.badge.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // XP & Coins Badges Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accentXp.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.accentXp),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$userXp XP',
                                    maxLines: 1,
                                    style: AppTypography.gameNumber.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.accentXp,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  size: 16, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$userCoins Coins',
                                    maxLines: 1,
                                    style: AppTypography.gameNumber.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.secondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                  ),
                ],
              ),
            ),

            // 2. Navigation List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  _buildDrawerSectionLabel('TACTICAL HUBS'),
                  _buildDrawerTile(
                    icon: Icons.radar_rounded,
                    title: 'Home Radar & Map',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.home);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.explore_rounded,
                    title: 'Mission Log (Quests)',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.quests);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Champions Hall',
                    iconColor: AppColors.secondary,
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.leaderboard);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.military_tech_rounded,
                    title: 'Trophy Vault & Badges',
                    iconColor: AppColors.accentXp,
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.achievements);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.groups_rounded,
                    title: 'Friends & Squad',
                    iconColor: AppColors.primary,
                    trailing: pendingRequestsCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentDanger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingRequestsCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.push(RoutePaths.friends);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.calendar_month_rounded,
                    title: 'Activity Calendar',
                    iconColor: AppColors.accentLocation,
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.push(RoutePaths.calendar);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.person_rounded,
                    title: 'Explorer Profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.profile);
                    },
                  ),


                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.border),
                  ),

                  _buildDrawerSectionLabel('DIAGNOSTICS & HELP'),
                  _buildDrawerTile(
                    icon: Icons.satellite_alt_rounded,
                    title: 'GPS Simulator Tool',
                    iconColor: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(context);
                      if (onOpenGpsSimulator != null) {
                        onOpenGpsSimulator!();
                      }
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.location_on_rounded,
                    title: activeGps != null ? 'GPS Locked & Active' : 'Location Diagnostics',
                    iconColor: activeGps != null ? AppColors.accentSuccess : AppColors.textMuted,
                    trailing: activeGps != null
                        ? const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.accentSuccess)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(locationPermissionNotifierProvider.notifier).openLocationSettings();
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.help_outline_rounded,
                    title: 'How to Play QuestUP',
                    onTap: () {
                      _showHowToPlayDialog(context);
                    },
                  ),
                ],
              ),
            ),

            // 3. Logout Button at the bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.accentDanger.withValues(alpha: 0.4)),
                ),
                tileColor: AppColors.accentDanger.withValues(alpha: 0.1),
                leading: const Icon(Icons.logout_rounded, color: AppColors.accentDanger),
                title: Text(
                  'Sign Out',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.accentDanger,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onTap: () => _showSignOutDialog(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDrawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
      ),
    );
  }

  static Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.border, size: 18),
      onTap: onTap,
    );
  }
}

