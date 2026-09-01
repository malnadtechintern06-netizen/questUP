import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class AvatarItem {
  final String key;
  final String title;
  final IconData icon;
  final Color color;

  const AvatarItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class AvatarSelectorSheet extends StatelessWidget {
  final String selectedKey;
  final Function(String key) onSelect;

  const AvatarSelectorSheet({
    super.key,
    required this.selectedKey,
    required this.onSelect,
  });

  static const List<AvatarItem> availableAvatars = [
    AvatarItem(
      key: 'avatar_ranger',
      title: 'Forest Ranger',
      icon: Icons.forest_rounded,
      color: AppColors.primary,
    ),
    AvatarItem(
      key: 'avatar_cyber_knight',
      title: 'Cyber Knight',
      icon: Icons.shield_rounded,
      color: AppColors.accentLocation,
    ),
    AvatarItem(
      key: 'avatar_mystic_sage',
      title: 'Mystic Sage',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.accentXp,
    ),
    AvatarItem(
      key: 'avatar_sky_pilot',
      title: 'Sky Navigator',
      icon: Icons.explore_rounded,
      color: AppColors.secondary,
    ),
    AvatarItem(
      key: 'avatar_fire_trail',
      title: 'Trail Blazer',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.accentDanger,
    ),
    AvatarItem(
      key: 'avatar_deep_diver',
      title: 'Abyss Seeker',
      icon: Icons.scuba_diving_rounded,
      color: Color(0xFF00E5FF),
    ),
  ];

  static IconData getIconForAvatar(String key) {
    return availableAvatars
        .firstWhere(
          (a) => a.key == key,
          orElse: () => availableAvatars.first,
        )
        .icon;
  }

  static Color getColorForAvatar(String key) {
    return availableAvatars
        .firstWhere(
          (a) => a.key == key,
          orElse: () => availableAvatars.first,
        )
        .color;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Choose Your Persona Avatar', style: AppTypography.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final avatar = availableAvatars[index];
                  final isSelected = avatar.key == selectedKey;

                  return InkWell(
                    onTap: () {
                      onSelect(avatar.key);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? avatar.color.withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? avatar.color : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: avatar.color.withValues(alpha: 0.2),
                            ),
                            child: Icon(avatar.icon, color: avatar.color, size: 28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            avatar.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
