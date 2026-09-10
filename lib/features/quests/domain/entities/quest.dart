enum QuestDifficulty {
  easy,
  medium,
  hard,
  legendary,
}

enum QuestCategory {
  location,
  photo,
  video,
  timed,
  reading,
  writing,
  drawing,
  exercise,
  gaming,
  food,
  walking,
  nature,
  observation,
  study,
  custom,
  // Legacy aliases
  landmark,
  culture,
  fitness,
  mystery,
}

enum QuestVerificationType {
  locationGps,
  photoProof,
  quiz,
  qrCode,
  secretCode,
  taskConfirmation,
  adminApproval,
  videoProof,
  timedActivity,
  timedVideo,
  writingText,
  drawingCanvas,
  walkingGps,
  gameplayTime,
  compositeRules,
  customConfig,
}

enum QuestRepeatability {
  oneTime,
  daily,
  weekly,
  repeatable,
}

class QuestRequirement {
  final String title;
  final String description;
  final bool requiresCameraProof;
  final bool requiresGpsLocation;

  const QuestRequirement({
    required this.title,
    required this.description,
    this.requiresCameraProof = true,
    this.requiresGpsLocation = true,
  });
}

class Quest {
  final String id;
  final String title;
  final String description;
  final String storyline;
  final QuestCategory category;
  final QuestDifficulty difficulty;
  final QuestVerificationType verificationType;
  final QuestRepeatability repeatability;
  final double latitude;
  final double longitude;
  final String locationName;
  final String? originLocationName;
  final String? historicalFact;
  final double radiusMeters; // allowedRadius
  final int xpReward;
  final int coinReward;
  final int requiredLevel;
  final bool isActive;
  final bool isCompleted;
  final List<QuestRequirement> requirements;
  final String iconKey;
  final double? distanceMeters; // Calculated relative to real player GPS

  // Exact Google Places / Place Metadata
  final String? placeId; // Exact Google Places place_id
  final String? placeCategory;
  final String? placeAddress; // Full vicinity / formatted address
  final List<String> placeTypes; // Specific Google Place types (e.g. ['hospital', 'health'])

  // Exact Photo Attributes & Priority
  final String? imageUrl;
  final String? photoReference; // Primary selected photo reference
  final List<String> photoReferences; // All photos belonging to this exact Place ID
  final String? photoUrl; // Constructed Google Places Photo URL
  final String imageSource; // 'google_places' | 'fallback'

  // Universal Verification Targets & Parameters
  final int requiredDurationSeconds; // e.g. 600 for 10 minutes
  final double requiredDistanceMeters; // e.g. 1000 for 1.0 km
  final int requiredWords; // e.g. 100 for 100 words
  final int requiredLines; // e.g. 10 for 10 lines
  final int requiredRepetitions; // e.g. 20 for 20 squats
  final String? requiredObject; // e.g. "flower", "cow", "tree", "apple", "book", "car", "bicycle", "food"
  final String? requiredPlace; // e.g. "college", "temple", "park", "museum", "hospital"
  final String? requiredTarget; // e.g. "entrance", "main gate", "statue", "signboard"
  final String? requiredDrawingSubject; // e.g. "tree", "cow", "flower", "house"

  // Composable Requirement Flags
  final bool requiresGPS;
  final bool requiresPhoto;
  final bool requiresFreshPhoto;
  final bool requiresVideo;
  final bool requiresDrawing;
  final bool requiresText;
  final bool requiresGameSession;
  final List<String> requiredVerificationRules;

  // Dynamic Location Quest Generation Attributes
  final String sourceType; // 'admin' | 'location_generated'
  final String? googlePlaceId;
  final double? generationLatitude;
  final double? generationLongitude;
  final String? userId;

  // Squad Co-op Assist Attributes
  final String? sharedByUserName;
  final String? sharedByUserTag;
  final String? sharedByUserId;
  final bool isSharedQuest;
  final String? sharedStatus;

  // Anti-Cheat & Server-Authoritative Verification Extensions
  final String? verificationSecret; // Secret code, QR payload, or verification hash
  final String? quizDataJson; // Quiz questions JSON
  final int minDurationSeconds; // Anti-cheat minimum required seconds
  final bool requiresAdminReview; // Requires manual admin approval
  final bool allowGalleryUpload; // Strict camera-only enforcement flag

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.storyline,
    required this.category,
    required this.difficulty,
    this.verificationType = QuestVerificationType.locationGps,
    this.repeatability = QuestRepeatability.oneTime,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.originLocationName,
    this.historicalFact,
    required this.radiusMeters,
    required this.xpReward,
    required this.coinReward,
    required this.requiredLevel,
    this.isActive = true,
    this.isCompleted = false,
    required this.requirements,
    required this.iconKey,
    this.distanceMeters,
    this.placeId,
    this.placeCategory,
    this.placeAddress,
    this.placeTypes = const [],
    this.imageUrl,
    this.photoReference,
    this.photoReferences = const [],
    this.photoUrl,
    this.imageSource = 'fallback',
    this.requiredDurationSeconds = 0,
    this.requiredDistanceMeters = 0,
    this.requiredWords = 0,
    this.requiredLines = 0,
    this.requiredRepetitions = 0,
    this.requiredObject,
    this.requiredPlace,
    this.requiredTarget,
    this.requiredDrawingSubject,
    this.requiresGPS = false,
    this.requiresPhoto = false,
    this.requiresFreshPhoto = false,
    this.requiresVideo = false,
    this.requiresDrawing = false,
    this.requiresText = false,
    this.requiresGameSession = false,
    this.requiredVerificationRules = const [],
    this.sourceType = 'admin',
    this.googlePlaceId,
    this.generationLatitude,
    this.generationLongitude,
    this.userId,
    this.sharedByUserName,
    this.sharedByUserTag,
    this.sharedByUserId,
    this.isSharedQuest = false,
    this.sharedStatus,
    this.verificationSecret,
    this.quizDataJson,
    this.minDurationSeconds = 0,
    this.requiresAdminReview = false,
    this.allowGalleryUpload = false,
  });

  double get allowedRadius => radiusMeters;
  bool get isWithinAllowedRadius =>
      distanceMeters != null && distanceMeters! <= radiusMeters;

  bool get hasObjectDetection =>
      requiredObject != null && requiredObject!.trim().isNotEmpty;
  bool get hasPlaceDetection =>
      requiredPlace != null && requiredPlace!.trim().isNotEmpty;
  bool get hasGpsRequirement =>
      requiresGPS || verificationType == QuestVerificationType.locationGps || verificationType == QuestVerificationType.walkingGps || (latitude != 0.0 && longitude != 0.0);
  bool get isCameraOnly =>
      !allowGalleryUpload && (requiresFreshPhoto || verificationType == QuestVerificationType.photoProof || hasObjectDetection);
  bool get requiresAntiScreenCheck =>
      requiresFreshPhoto || hasObjectDetection || verificationType == QuestVerificationType.photoProof;

  bool get isGooglePlacesPhoto => imageSource == 'google_places';

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    String? storyline,
    QuestCategory? category,
    QuestDifficulty? difficulty,
    QuestVerificationType? verificationType,
    QuestRepeatability? repeatability,
    double? latitude,
    double? longitude,
    String? locationName,
    String? originLocationName,
    String? historicalFact,
    double? radiusMeters,
    int? xpReward,
    int? coinReward,
    int? requiredLevel,
    bool? isActive,
    bool? isCompleted,
    List<QuestRequirement>? requirements,
    String? iconKey,
    double? distanceMeters,
    String? placeId,
    String? placeCategory,
    String? placeAddress,
    List<String>? placeTypes,
    String? imageUrl,
    String? photoReference,
    List<String>? photoReferences,
    String? photoUrl,
    String? imageSource,
    int? requiredDurationSeconds,
    double? requiredDistanceMeters,
    int? requiredWords,
    int? requiredLines,
    int? requiredRepetitions,
    String? requiredObject,
    String? requiredPlace,
    String? requiredTarget,
    String? requiredDrawingSubject,
    bool? requiresGPS,
    bool? requiresPhoto,
    bool? requiresFreshPhoto,
    bool? requiresVideo,
    bool? requiresDrawing,
    bool? requiresText,
    bool? requiresGameSession,
    List<String>? requiredVerificationRules,
    String? sourceType,
    String? googlePlaceId,
    double? generationLatitude,
    double? generationLongitude,
    String? userId,
    String? sharedByUserName,
    String? sharedByUserTag,
    String? sharedByUserId,
    bool? isSharedQuest,
    String? sharedStatus,
    String? verificationSecret,
    String? quizDataJson,
    int? minDurationSeconds,
    bool? requiresAdminReview,
    bool? allowGalleryUpload,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      storyline: storyline ?? this.storyline,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      verificationType: verificationType ?? this.verificationType,
      repeatability: repeatability ?? this.repeatability,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      originLocationName: originLocationName ?? this.originLocationName,
      historicalFact: historicalFact ?? this.historicalFact,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      requirements: requirements ?? this.requirements,
      iconKey: iconKey ?? this.iconKey,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      placeId: placeId ?? this.placeId,
      placeCategory: placeCategory ?? this.placeCategory,
      placeAddress: placeAddress ?? this.placeAddress,
      placeTypes: placeTypes ?? this.placeTypes,
      imageUrl: imageUrl ?? this.imageUrl,
      photoReference: photoReference ?? this.photoReference,
      photoReferences: photoReferences ?? this.photoReferences,
      photoUrl: photoUrl ?? this.photoUrl,
      imageSource: imageSource ?? this.imageSource,
      requiredDurationSeconds:
          requiredDurationSeconds ?? this.requiredDurationSeconds,
      requiredDistanceMeters:
          requiredDistanceMeters ?? this.requiredDistanceMeters,
      requiredWords: requiredWords ?? this.requiredWords,
      requiredLines: requiredLines ?? this.requiredLines,
      requiredRepetitions: requiredRepetitions ?? this.requiredRepetitions,
      requiredObject: requiredObject ?? this.requiredObject,
      requiredPlace: requiredPlace ?? this.requiredPlace,
      requiredTarget: requiredTarget ?? this.requiredTarget,
      requiredDrawingSubject:
          requiredDrawingSubject ?? this.requiredDrawingSubject,
      requiresGPS: requiresGPS ?? this.requiresGPS,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      requiresFreshPhoto: requiresFreshPhoto ?? this.requiresFreshPhoto,
      requiresVideo: requiresVideo ?? this.requiresVideo,
      requiresDrawing: requiresDrawing ?? this.requiresDrawing,
      requiresText: requiresText ?? this.requiresText,
      requiresGameSession: requiresGameSession ?? this.requiresGameSession,
      requiredVerificationRules:
          requiredVerificationRules ?? this.requiredVerificationRules,
      sourceType: sourceType ?? this.sourceType,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      generationLatitude: generationLatitude ?? this.generationLatitude,
      generationLongitude: generationLongitude ?? this.generationLongitude,
      userId: userId ?? this.userId,
      sharedByUserName: sharedByUserName ?? this.sharedByUserName,
      sharedByUserTag: sharedByUserTag ?? this.sharedByUserTag,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      isSharedQuest: isSharedQuest ?? this.isSharedQuest,
      sharedStatus: sharedStatus ?? this.sharedStatus,
      verificationSecret: verificationSecret ?? this.verificationSecret,
      quizDataJson: quizDataJson ?? this.quizDataJson,
      minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
      requiresAdminReview: requiresAdminReview ?? this.requiresAdminReview,
      allowGalleryUpload: allowGalleryUpload ?? this.allowGalleryUpload,
    );
  }
}
