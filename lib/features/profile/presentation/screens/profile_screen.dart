import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/router/app_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';

import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/app_external_service.dart';
import 'package:quest_up/core/widgets/animated_xp_bar.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/auth/presentation/providers/auth_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:flutter/services.dart';
import 'package:quest_up/features/friends/presentation/providers/friends_providers.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';
import 'package:quest_up/features/profile/presentation/widgets/profile_stat_card.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showAvatarPicker(BuildContext context, WidgetRef ref, String currentKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AvatarSelectorSheet(
        selectedKey: currentKey,
        onSelect: (newKey) {
          ref.read(userProfileNotifierProvider.notifier).updateProfile(avatarKey: newKey);
        },
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Explorer Alias',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Enter callsign / alias',
            hintStyle: AppTypography.bodyMedium,
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userProfileNotifierProvider.notifier).updateProfile(name: newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Save Alias', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final userProfileAsync = ref.watch(userProfileNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Explorer Profile',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ref.read(userProfileNotifierProvider.notifier).loadProfile(),
          ),
        ],
      ),
      body: userProfileAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              ShimmerBox(width: 104, height: 104, borderRadius: 52),
              SizedBox(height: 16),
              ShimmerBox(width: 180, height: 24, borderRadius: 8),
              SizedBox(height: 24),
              ShimmerBox(width: double.infinity, height: 120, borderRadius: 16),
            ],
          ),
        ),
        error: (err, stack) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.read(userProfileNotifierProvider.notifier).loadProfile(),
        ),
        data: (profile) {
          final avatarColor = AvatarSelectorSheet.getColorForAvatar(profile.avatarKey);
          final avatarIcon = AvatarSelectorSheet.getIconForAvatar(profile.avatarKey);

          final displayEmail = (authState.user?.email.isNotEmpty ?? false)
              ? authState.user!.email
              : (profile.email != 'explorer@questup.com'
                  ? profile.email
                  : (authState.user?.email ?? profile.email));
          final displayName = (authState.user?.displayName.isNotEmpty ?? false)
              ? authState.user!.displayName
              : profile.name;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(userProfileNotifierProvider.notifier).loadProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 3D Avatar Showcase with Edit Button
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: avatarColor.withValues(alpha: 0.15),
                            border: Border.all(color: avatarColor, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: avatarColor.withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(avatarIcon, size: 56, color: avatarColor),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showAvatarPicker(context, ref, profile.avatarKey),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.background, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name with edit pencil
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.displayMedium.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                        onPressed: () => _showEditNameDialog(context, ref, displayName),
                      ),
                    ],
                  ),
                  Text(
                    displayEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Unique Player Tag & Squad Quick Action
                  Consumer(
                    builder: (context, ref, _) {
                      final friendsState = ref.watch(friendsNotifierProvider);
                      final displayTag = profile.playerId != 'QST-0000'
                          ? profile.playerId
                          : (friendsState.myPlayerTag != 'QST-0000'
                              ? friendsState.myPlayerTag
                              : 'QST-1001');

                      return Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: displayTag));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Player ID "$displayTag" copied! 📋'),
                                  backgroundColor: AppColors.surfaceElevated,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_rounded, size: 14, color: AppColors.secondary),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Player ID  $displayTag',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => appRouter.push(RoutePaths.friends),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.groups_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Squad (${friendsState.friends.length})',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (friendsState.incomingRequestsCount > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentDanger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${friendsState.incomingRequestsCount}',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),


                  // 3D Level & XP Progression Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderBright, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'EXPLORER PROGRESSION',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.badge.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Tier Rank',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedXpBar(
                          currentXp: profile.currentXp,
                          requiredXp: profile.xpToNextLevel,
                          level: profile.level,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Stats Grid 2x2
                  Row(
                    children: [
                      Expanded(
                        child: ProfileStatCard(
                          title: 'Quests Cleared',
                          value: '${profile.completedQuestIds.length}',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.accentSuccess,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ProfileStatCard(
                          title: 'Total XP',
                          value: '${profile.currentXp}',
                          icon: Icons.bolt_rounded,
                          color: AppColors.accentXp,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ProfileStatCard(
                          title: 'Gold Coins',
                          value: '${profile.coins}',
                          icon: Icons.monetization_on_rounded,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ProfileStatCard(
                          title: 'Mastery Level',
                          value: 'LVL ${profile.level}',
                          icon: Icons.shield_rounded,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ABOUT & SUPPORT Section
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                          child: Text(
                            'ABOUT & SUPPORT',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        _buildMenuTile(
                          icon: Icons.shield_outlined,
                          iconColor: AppColors.accentSuccess,
                          title: 'Privacy Policy',
                          subtitle: 'Learn how QuestUP handles your data',
                          onTap: () => const AppExternalService().openPrivacyPolicy(context: context),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.star_rounded,
                          iconColor: AppColors.secondary,
                          title: 'Rate Us',
                          subtitle: 'Enjoying QuestUP? Rate the app',
                          onTap: () => const AppExternalService().openRateUs(context: context),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.share_rounded,
                          iconColor: AppColors.primary,
                          title: 'Share QuestUP',
                          subtitle: 'Invite friends to join your quests',
                          onTap: () => const AppExternalService().shareQuestUp(context: context),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.logout_rounded,
                          iconColor: AppColors.accentDanger,
                          title: 'Sign Out',
                          subtitle: 'Log out of your QuestUP account',
                          onTap: () => _showSignOutDialog(context, ref),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Member telemetry info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Member since ${profile.joinedAt.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'QuestUP v1.0.0',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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


  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
