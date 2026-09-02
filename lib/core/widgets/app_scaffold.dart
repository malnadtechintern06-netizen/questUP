import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';

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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          elevation: 4,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.my_location_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.my_location_rounded, color: AppColors.primary),
              label: 'Radar',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.explore_rounded, color: AppColors.primary),
              label: 'Quests',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
              label: 'Rankings',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.emoji_events_rounded, color: AppColors.primary),
              label: 'Badges',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
