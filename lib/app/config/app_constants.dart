class AppConstants {
  static const String appName = 'QuestUP';
  static const String appTagline = 'Turn the Real World Into a Game';
  
  // Storage Keys
  static const String keyUserProfile = 'questup_user_profile_v1';
  static const String keyQuests = 'questup_quests_v1';
  static const String keyCompletions = 'questup_completions_v1';
  static const String keyAchievements = 'questup_achievements_v1';
  static const String keyLeaderboard = 'questup_leaderboard_v1';
  static const String keyInitialDataSeeded = 'questup_initial_seeded_v1';
  static const String keyLocationPermissionGranted = 'questup_location_permission_granted_v1';
  static const String keyAuthSession = 'questup_auth_session_v1';

  // Game Progression Rules
  static const int baseLevelXp = 500;
  static const double xpMultiplierPerLevel = 1.25;
  static const double defaultVerificationRadiusMeters = 75.0; // 75 meters geofence

  // Category Names
  static const String catNature = 'Nature & Outdoors';
  static const String catLandmark = 'Historical Landmark';
  static const String catCulture = 'Arts & Culture';
  static const String catFitness = 'Fitness & Trail';
  static const String catMystery = 'Urban Mystery';

  // Google Maps & Geocoding API Key (optional - falls back to OpenStreetMap geocoding when empty)
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
}
