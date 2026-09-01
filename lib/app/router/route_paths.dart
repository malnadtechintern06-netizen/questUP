class RoutePaths {
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String locationPermission = '/location-permission';

  static const String home = '/';
  static const String quests = '/quests';
  static const String questDetail = '/quests/:id';
  static const String questVerify = '/quests/:id/verify';
  static const String leaderboard = '/leaderboard';
  static const String achievements = '/achievements';
  static const String profile = '/profile';
  static const String rewards = '/rewards';

  static String questDetailPath(String id) => '/quests/$id';
  static String questVerifyPath(String id) => '/quests/$id/verify';
}
