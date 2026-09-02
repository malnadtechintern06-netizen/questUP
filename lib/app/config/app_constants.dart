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
  static const String keyCalendarEntries = 'questup_calendar_entries_v1';
  static const String keyQuestSessions = 'questup_quest_sessions_v1';
  static const String keyQuestProofs = 'questup_quest_proofs_v1';

  // Android Package & Store URLs
  static const String androidApplicationId = 'com.questup.quest_up';
  static const String playStoreMarketUri = 'market://details?id=$androidApplicationId';
  static const String playStoreWebUrl = 'https://play.google.com/store/apps/details?id=$androidApplicationId';

  // Privacy Policy URL (Centralized configuration placeholder - replace with your live public Privacy Policy URL)
  static const String privacyPolicyUrl =
      String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: 'https://questup.app/privacy-policy');

  // Share Text
  static const String shareSubject = 'Join me on QuestUP - Real World Quests & Adventures';
  static const String shareMessage =
      "🚀 I'm using QuestUP!\n\n"
      "Turn the real world into a game with quests, challenges, XP, coins, badges and rankings.\n\n"
      "Join me on QuestUP and start your adventure!\n"
      "$playStoreWebUrl";

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
