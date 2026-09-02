import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router/app_router.dart';
import '../../app/router/route_paths.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/location_permission/presentation/providers/location_permission_provider.dart';
import '../../features/profile/presentation/providers/user_providers.dart';
import '../../features/quests/presentation/providers/quest_providers.dart';

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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
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
            const Text('How to Play QuestUP'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideTile(
                icon: Icons.my_location_rounded,
                color: AppColors.accentLocation,
                title: '1. Discover Real-World Quests',
                desc: 'Turn on GPS to find quests at nearby landmarks, parks, and cultural sites.',
              ),
              const SizedBox(height: 12),
              _buildGuideTile(
                icon: Icons.camera_alt_rounded,
                color: AppColors.primary,
                title: '2. Complete & Verify',
                desc: 'Travel to waypoints within GPS radius and submit proof with camera, sketches, or steps.',
              ),
              const SizedBox(height: 12),
              _buildGuideTile(
                icon: Icons.emoji_events_rounded,
                color: AppColors.secondary,
                title: '3. Level Up & Climb Ranks',
                desc: 'Earn XP, collect Coins, unlock prestigious badges, and top the weekly leaderboard.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'GOT IT',
              style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontSize: 14),
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
                  height: 1.3,
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
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of QuestUP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close drawer if open
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
    final profile = userProfileAsync.valueOrNull;
    final userName = (authState.user?.displayName.isNotEmpty ?? false)
        ? authState.user!.displayName
        : (profile?.name ?? 'Explorer');
    final userLevel = profile?.level ?? 1;
    final userXp = profile?.currentXp ?? 0;
    final userCoins = profile?.coins ?? 0;

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 1. User Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
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
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Level $userLevel Explorer',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '$userXp XP',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  size: 16, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text(
                                '$userCoins Coins',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
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
                  _buildDrawerSectionLabel('ADVENTURE HUBS'),
                  _buildDrawerTile(
                    icon: Icons.my_location_rounded,
                    title: 'Home Radar & Map',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.home);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.explore_rounded,
                    title: 'Nearby Quests',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.quests);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.bar_chart_rounded,
                    title: 'Champions Leaderboard',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.leaderboard);
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.emoji_events_rounded,
                    title: 'Badges & Achievements',
                    onTap: () {
                      Navigator.of(context).pop();
                      appRouter.go(RoutePaths.achievements);
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

                  _buildDrawerSectionLabel('TOOLS & SETTINGS'),
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
                    title: activeGps != null ? 'GPS Active (Locked)' : 'Location Diagnostics',
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
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.accentDanger.withValues(alpha: 0.3)),
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
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.border, size: 18),
      onTap: onTap,
    );
  }
}
