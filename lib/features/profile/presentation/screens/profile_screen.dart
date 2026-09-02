import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/app_external_service.dart';
import 'package:quest_up/core/widgets/animated_xp_bar.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/auth/presentation/providers/auth_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Explorer Name', style: AppTypography.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Enter your alias',
            hintStyle: AppTypography.bodyMedium,
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
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
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userProfileNotifierProvider.notifier).updateProfile(name: newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
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
      appBar: AppBar(
        title: const Text('Explorer Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(userProfileNotifierProvider.notifier).loadProfile(),
          ),
        ],
      ),
      body: userProfileAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              ShimmerBox(width: 100, height: 100, borderRadius: 50),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Edit Button
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: avatarColor.withValues(alpha: 0.15),
                          border: Border.all(color: avatarColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: avatarColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(avatarIcon, size: 52, color: avatarColor),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _showAvatarPicker(context, ref, profile.avatarKey),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 2),
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
                const SizedBox(height: 16),

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
                        style: AppTypography.displayMedium.copyWith(fontSize: 22),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
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
                const SizedBox(height: 20),

                // Level & XP Progress Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Progression Status',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Explorer Tier',
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
                const SizedBox(height: 16),

                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: ProfileStatCard(
                        title: 'Total Quests',
                        value: '${profile.completedQuestIds.length}',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProfileStatCard(
                        title: 'Total Coins',
                        value: '${profile.coins}',
                        icon: Icons.monetization_on_rounded,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ProfileStatCard(
                        title: 'Badges Earned',
                        value: '${profile.earnedBadgeIds.length}',
                        icon: Icons.military_tech_rounded,
                        color: AppColors.accentXp,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProfileStatCard(
                        title: 'Current Level',
                        value: 'LVL ${profile.level}',
                        icon: Icons.shield_rounded,
                        color: AppColors.accentLocation,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ABOUT & SUPPORT Section (Privacy Policy, Rate Us, Share QuestUP)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                        child: Text(
                          'ABOUT & SUPPORT',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
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
                        iconColor: AppColors.accentLocation,
                        title: 'Share QuestUP',
                        subtitle: 'Invite friends to join your quests',
                        onTap: () => const AppExternalService().shareQuestUp(context: context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Member info
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
                        style: AppTypography.caption.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
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
                      style: AppTypography.titleMedium.copyWith(fontSize: 14),
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
