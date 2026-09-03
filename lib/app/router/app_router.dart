import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_names.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/core/widgets/app_scaffold.dart';
import 'package:quest_up/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/login_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/register_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/splash_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/welcome_screen.dart';
import 'package:quest_up/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:quest_up/features/location_permission/presentation/screens/location_permission_screen.dart';
import 'package:quest_up/features/profile/presentation/screens/profile_screen.dart';
import 'package:quest_up/features/quests/presentation/screens/home_radar_screen.dart';
import 'package:quest_up/features/quests/presentation/screens/quest_detail_screen.dart';
import 'package:quest_up/features/quests/presentation/screens/quest_list_screen.dart';
import 'package:quest_up/features/calendar/presentation/screens/quest_calendar_screen.dart';
import 'package:quest_up/features/verification/presentation/screens/quest_verification_screen.dart';
import 'package:quest_up/features/friends/presentation/screens/friends_screen.dart';
import 'package:quest_up/features/friends/presentation/screens/friend_detail_screen.dart';


final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: RoutePaths.splash,
  routes: [
    // Splash Screen
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // Welcome Screen
    GoRoute(
      path: RoutePaths.welcome,
      name: RouteNames.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),

    // Login Screen
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),

    // Register Screen
    GoRoute(
      path: RoutePaths.register,
      name: RouteNames.register,
      builder: (context, state) => const RegisterScreen(),
    ),

    // Location Permission Onboarding Screen
    GoRoute(
      path: RoutePaths.locationPermission,
      name: RouteNames.locationPermission,
      builder: (context, state) => const LocationPermissionScreen(),
    ),

    // Stateful Shell Route for Main Bottom Nav tabs
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppScaffold(
          navigationShell: navigationShell,
        );
      },
      branches: [
        // Branch 0: Radar / Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.home,
              name: RouteNames.home,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeRadarScreen(),
              ),
            ),
          ],
        ),

        // Branch 1: Quests
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.quests,
              name: RouteNames.quests,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: QuestListScreen(),
              ),
            ),
          ],
        ),

        // Branch 2: Leaderboard / Rankings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.leaderboard,
              name: RouteNames.leaderboard,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LeaderboardScreen(),
              ),
            ),
          ],
        ),

        // Branch 3: Achievements / Badges
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.achievements,
              name: RouteNames.achievements,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AchievementsScreen(),
              ),
            ),
          ],
        ),

        // Branch 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.profile,
              name: RouteNames.profile,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // Sub-screens pushed on top of the root navigator
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.questDetail,
      name: RouteNames.questDetail,
      builder: (context, state) {
        final questId = state.pathParameters['id'] ?? '';
        return QuestDetailScreen(questId: questId);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.questVerify,
      name: RouteNames.questVerify,
      builder: (context, state) {
        final questId = state.pathParameters['id'] ?? '';
        return QuestVerificationScreen(questId: questId);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.calendar,
      name: RouteNames.calendar,
      builder: (context, state) => const QuestCalendarScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.friends,
      name: RouteNames.friends,
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.friendDetail,
      name: RouteNames.friendDetail,
      builder: (context, state) {
        final friendId = state.pathParameters['id'] ?? '';
        return FriendDetailScreen(friendUserId: friendId);
      },
    ),
  ],
);

