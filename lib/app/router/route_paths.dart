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
  static const String calendar = '/calendar';
  static const String profile = '/profile';
  static const String rewards = '/rewards';
  static const String friends = '/friends';
  static const String friendDetail = '/friends/:id';

  static String questDetailPath(String id) => '/quests/$id';
  static String questVerifyPath(String id) => '/quests/$id/verify';
  static String friendDetailPath(String id) => '/friends/$id';
}

