import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceGlass : AppColors.lightSurface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.borderBright : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              if (isDark)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  index: 0,
                  currentIndex: currentIndex,
                  label: 'Radar',
                  icon: Icons.my_location_outlined,
                  activeIcon: Icons.my_location_rounded,
                  activeColor: AppColors.primary,
                ),
                _buildNavItem(
                  index: 1,
                  currentIndex: currentIndex,
                  label: 'Quests',
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  activeColor: AppColors.accentXp,
                ),
                _buildNavItem(
                  index: 2,
                  currentIndex: currentIndex,
                  label: 'Rankings',
                  icon: Icons.leaderboard_outlined,
                  activeIcon: Icons.leaderboard_rounded,
                  activeColor: AppColors.secondary,
                ),
                _buildNavItem(
                  index: 3,
                  currentIndex: currentIndex,
                  label: 'Badges',
                  icon: Icons.emoji_events_outlined,
                  activeIcon: Icons.emoji_events_rounded,
                  activeColor: AppColors.accentPurple,
                ),
                _buildNavItem(
                  index: 4,
                  currentIndex: currentIndex,
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  activeColor: AppColors.accentSuccess,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required Color activeColor,
  }) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 8 : 0,
                  vertical: isSelected ? 3 : 0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: activeColor.withValues(alpha: 0.6), width: 1.2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: isSelected ? 21 : 20,
                  color: isSelected ? activeColor : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? activeColor : AppColors.textMuted,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


