import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/route_paths.dart';
import '../../app/theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final String location;

  const AppScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  int _calculateSelectedIndex(BuildContext context) {
    if (location == RoutePaths.home) return 0;
    if (location.startsWith('/quests')) return 1;
    if (location.startsWith('/leaderboard')) return 2;
    if (location.startsWith('/achievements')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RoutePaths.home);
        break;
      case 1:
        context.go(RoutePaths.quests);
        break;
      case 2:
        context.go(RoutePaths.leaderboard);
        break;
      case 3:
        context.go(RoutePaths.achievements);
        break;
      case 4:
        context.go(RoutePaths.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onItemTapped(index, context),
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
