import '../../domain/entities/quest.dart';

class QuestRequirementModel extends QuestRequirement {
  const QuestRequirementModel({
    required super.title,
    required super.description,
    super.requiresCameraProof = true,
    super.requiresGpsLocation = true,
  });

  factory QuestRequirementModel.fromJson(Map<String, dynamic> json) {
    return QuestRequirementModel(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiresCameraProof: json['requiresCameraProof'] as bool? ?? true,
      requiresGpsLocation: json['requiresGpsLocation'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'requiresCameraProof': requiresCameraProof,
      'requiresGpsLocation': requiresGpsLocation,
    };
  }
}

class QuestModel extends Quest {
  const QuestModel({
    required super.id,
    required super.title,
    required super.description,
    required super.storyline,
    required super.category,
    required super.difficulty,
    super.verificationType = QuestVerificationType.locationGps,
    super.repeatability = QuestRepeatability.oneTime,
    required super.latitude,
    required super.longitude,
    required super.locationName,
    super.originLocationName,
    super.historicalFact,
    required super.radiusMeters,
    required super.xpReward,
    required super.coinReward,
    required super.requiredLevel,
    super.isActive = true,
    super.isCompleted = false,
    required super.requirements,
    required super.iconKey,
    super.distanceMeters,
    super.placeId,
    super.placeCategory,
    super.placeAddress,
    super.placeTypes = const [],
    super.imageUrl,
    super.photoReference,
    super.photoReferences = const [],
    super.photoUrl,
    super.imageSource = 'fallback',
    super.requiredDurationSeconds = 0,
    super.requiredDistanceMeters = 0,
    super.requiredWords = 0,
    super.requiredLines = 0,
    super.requiredRepetitions = 0,
    super.requiredObject,
    super.requiredPlace,
    super.requiredTarget,
    super.requiredDrawingSubject,
    super.requiresGPS = false,
    super.requiresPhoto = false,
    super.requiresFreshPhoto = false,
    super.requiresVideo = false,
    super.requiresDrawing = false,
    super.requiresText = false,
    super.requiresGameSession = false,
    super.requiredVerificationRules = const [],
    super.sourceType = 'admin',
    super.googlePlaceId,
    super.generationLatitude,
    super.generationLongitude,
    super.userId,
  });

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    final questId = (json['id'] ?? json['questId'] ?? '').toString();
    final radius = double.tryParse(json['radiusMeters']?.toString() ?? json['radius_meters']?.toString() ?? json['allowedRadius']?.toString() ?? '') ?? 75.0;
    
    final dynamic activeRaw = json['isActive'] ?? json['is_active'] ?? json['active'];
    final bool active = activeRaw == null ||
        activeRaw == true ||
        activeRaw == 1 ||
        activeRaw == '1' ||
        activeRaw == 'true';

    final catStr = (json['category'] as String? ?? 'landmark').toLowerCase();
    final category = QuestCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == catStr,
      orElse: () {
        if (catStr == 'exploration') return QuestCategory.location;
        if (catStr == 'creativity') return QuestCategory.drawing;
        if (catStr == 'intellect') return QuestCategory.writing;
        if (catStr == 'social') return QuestCategory.custom;
        return QuestCategory.landmark;
      },
    );

    final verTypeStr = (json['verificationType'] as String? ?? json['verification_type'] as String? ?? 'locationGps').toLowerCase();
    final verificationType = QuestVerificationType.values.firstWhere(
      (e) => e.name.toLowerCase() == verTypeStr,
      orElse: () {
        if (verTypeStr == 'photo' || verTypeStr == 'photoproof') return QuestVerificationType.photoProof;
        if (verTypeStr == 'drawing' || verTypeStr == 'drawingcanvas') return QuestVerificationType.drawingCanvas;
        if (verTypeStr == 'writing' || verTypeStr == 'writingtext') return QuestVerificationType.writingText;
        if (verTypeStr == 'walking' || verTypeStr == 'walkinggps') return QuestVerificationType.walkingGps;
        if (verTypeStr == 'gaming' || verTypeStr == 'gameplaytime') return QuestVerificationType.gameplayTime;
        if (verTypeStr == 'qrcode' || verTypeStr == 'codephrase') return QuestVerificationType.compositeRules;
        if (category == QuestCategory.drawing) return QuestVerificationType.drawingCanvas;
        if (category == QuestCategory.writing) return QuestVerificationType.writingText;
        if (category == QuestCategory.walking) return QuestVerificationType.walkingGps;
        if (category == QuestCategory.gaming) return QuestVerificationType.gameplayTime;
        if (category == QuestCategory.video) return QuestVerificationType.videoProof;
        if (category == QuestCategory.timed) return QuestVerificationType.timedActivity;
        if (category == QuestCategory.reading || category == QuestCategory.exercise || category == QuestCategory.study) {
          return QuestVerificationType.timedVideo;
        }
        if (category == QuestCategory.photo || category == QuestCategory.food || category == QuestCategory.observation) {
          return QuestVerificationType.photoProof;
        }
        return QuestVerificationType.locationGps;
      },
    );

    final repStr = (json['repeatability'] as String? ?? 'oneTime').toLowerCase();
    final repeatability = QuestRepeatability.values.firstWhere(
      (e) => e.name.toLowerCase() == repStr,
      orElse: () => QuestRepeatability.oneTime,
    );

    final rulesList = (json['requiredVerificationRules'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final pTypes = (json['placeTypes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final pRefs = (json['photoReferences'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final photoUrlVal = json['photoUrl'] as String? ?? json['imageUrl'] as String? ?? json['image_asset_path'] as String?;
    final photoRefVal = json['photoReference'] as String? ?? json['photo_reference'] as String?;
    final imgSource = json['imageSource'] as String? ??
        (photoRefVal != null && photoRefVal.isNotEmpty ? 'google_places' : 'fallback');

    final diffStr = (json['difficulty'] ?? 'medium').toString().toLowerCase();
    final difficulty = QuestDifficulty.values.firstWhere(
      (e) => e.name.toLowerCase() == diffStr,
      orElse: () => QuestDifficulty.medium,
    );

    final xp = int.tryParse(json['xpReward']?.toString() ?? json['xp_reward']?.toString() ?? '') ?? 100;
    final coins = int.tryParse(json['coinReward']?.toString() ?? json['coins_reward']?.toString() ?? json['coin_reward']?.toString() ?? '') ?? 50;
    final level = int.tryParse(json['requiredLevel']?.toString() ?? json['required_level']?.toString() ?? '') ?? 1;
    final lat = double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0;
    final locationName = json['locationName'] as String? ?? json['location_name'] as String? ?? 'Local Waypoint';

    final reqObj = json['requiredObject'] as String? ?? json['required_object'] as String?;
    final reqDrawing = json['requiredDrawingSubject'] as String? ?? json['required_drawing_subject'] as String?;
    final reqPlace = json['requiredPlace'] as String? ?? json['required_place'] as String?;
    final reqTarget = json['requiredTarget'] as String? ?? json['required_target'] as String?;
    final reqDur = int.tryParse(json['requiredDurationSeconds']?.toString() ?? json['required_duration_seconds']?.toString() ?? '') ?? 0;
    final reqDist = double.tryParse(json['requiredDistanceMeters']?.toString() ?? json['required_distance_meters']?.toString() ?? '') ?? 0.0;
    final reqWords = int.tryParse(json['requiredWords']?.toString() ?? json['required_words']?.toString() ?? '') ?? 0;
    final reqLines = int.tryParse(json['requiredLines']?.toString() ?? json['required_lines']?.toString() ?? '') ?? 0;
    final reqReps = int.tryParse(json['requiredRepetitions']?.toString() ?? json['required_repetitions']?.toString() ?? '') ?? 0;

    final reqGps = json['requiresGPS'] == true || json['requires_gps'] == 1 || json['requires_gps'] == '1' || json['requires_gps'] == true;
    final reqPhoto = json['requiresPhoto'] == true || json['requires_photo'] == 1 || json['requires_photo'] == '1' || json['requires_photo'] == true;
    final reqFreshPhoto = json['requiresFreshPhoto'] == true || json['requires_fresh_photo'] == 1 || json['requires_fresh_photo'] == '1' || json['requires_fresh_photo'] == true;
    final reqVideo = json['requiresVideo'] == true || json['requires_video'] == 1 || json['requires_video'] == '1' || json['requires_video'] == true;
    final reqDraw = json['requiresDrawing'] == true || json['requires_drawing'] == 1 || json['requires_drawing'] == '1' || json['requires_drawing'] == true;
    final reqTxt = json['requiresText'] == true || json['requires_text'] == 1 || json['requires_text'] == '1' || json['requires_text'] == true;
    final reqGame = json['requiresGameSession'] == true || json['requires_game_session'] == 1 || json['requires_game_session'] == '1' || json['requires_game_session'] == true;

    final dynamicReqs = _buildDynamicRequirements(
      verificationType: verificationType,
      category: category,
      requiredObject: reqObj,
      requiredDrawingSubject: reqDrawing,
      requiredWords: reqWords,
      requiredDurationSeconds: reqDur,
      requiredDistanceMeters: reqDist,
      requiresGPS: reqGps,
      requiresPhoto: reqPhoto,
      requiresDrawing: reqDraw,
      requiresText: reqTxt,
      requiresVideo: reqVideo,
      requiresGameSession: reqGame,
    );

    return QuestModel(
      id: questId,
      title: json['title'] as String? ?? 'Exploration Waypoint',
      description: json['description'] as String? ?? '',
      storyline: json['storyline'] as String? ?? (json['description'] as String? ?? ''),
      category: category,
      difficulty: difficulty,
      verificationType: verificationType,
      repeatability: repeatability,
      latitude: lat,
      longitude: lng,
      locationName: locationName,
      originLocationName: json['originLocationName'] as String? ?? json['origin_location_name'] as String?,
      historicalFact: json['historicalFact'] as String? ?? json['historical_fact'] as String?,
      radiusMeters: radius,
      xpReward: xp,
      coinReward: coins,
      requiredLevel: level,
      isActive: active,
      isCompleted: json['isCompleted'] == true || json['isCompleted'] == 1 || json['isCompleted'] == '1',
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => QuestRequirementModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          dynamicReqs,
      iconKey: json['iconKey'] as String? ?? json['icon_key'] as String? ?? 'landmark',
      distanceMeters: double.tryParse(json['distanceMeters']?.toString() ?? json['distance_meters']?.toString() ?? ''),
      placeId: json['placeId'] as String? ?? json['place_id'] as String?,
      placeCategory: json['placeCategory'] as String? ?? json['place_category'] as String?,
      placeAddress: json['placeAddress'] as String? ?? json['address'] as String?,
      placeTypes: pTypes,
      imageUrl: photoUrlVal,
      photoReference: photoRefVal,
      photoReferences: pRefs,
      photoUrl: photoUrlVal,
      imageSource: imgSource,
      requiredDurationSeconds: reqDur,
      requiredDistanceMeters: reqDist,
      requiredWords: reqWords,
      requiredLines: reqLines,
      requiredRepetitions: reqReps,
      requiredObject: reqObj,
      requiredPlace: reqPlace,
      requiredTarget: reqTarget,
      requiredDrawingSubject: reqDrawing,
      requiresGPS: reqGps,
      requiresPhoto: reqPhoto,
      requiresFreshPhoto: reqFreshPhoto,
      requiresVideo: reqVideo,
      requiresDrawing: reqDraw,
      requiresText: reqTxt,
      requiresGameSession: reqGame,
      requiredVerificationRules: rulesList,
      sourceType: json['sourceType'] as String? ?? json['source_type'] as String? ?? 'admin',
      googlePlaceId: json['googlePlaceId'] as String? ?? json['google_place_id'] as String? ?? (json['placeId'] as String? ?? json['place_id'] as String?),
      generationLatitude: double.tryParse(json['generationLatitude']?.toString() ?? json['generation_latitude']?.toString() ?? ''),
      generationLongitude: double.tryParse(json['generationLongitude']?.toString() ?? json['generation_longitude']?.toString() ?? ''),
      userId: json['userId'] as String? ?? json['user_id'] as String?,
    );
  }

  static List<QuestRequirementModel> _buildDynamicRequirements({
    required QuestVerificationType verificationType,
    required QuestCategory category,
    String? requiredObject,
    String? requiredDrawingSubject,
    int requiredWords = 0,
    int requiredDurationSeconds = 0,
    double requiredDistanceMeters = 0.0,
    bool requiresGPS = false,
    bool requiresPhoto = false,
    bool requiresDrawing = false,
    bool requiresText = false,
    bool requiresVideo = false,
    bool requiresGameSession = false,
  }) {
    final list = <QuestRequirementModel>[];

    if (requiresGPS || verificationType == QuestVerificationType.locationGps) {
      list.add(const QuestRequirementModel(
        title: 'Reach GPS Location',
        description: 'Travel within the target waypoint coordinates',
        requiresCameraProof: false,
        requiresGpsLocation: true,
      ));
    }

    if (requiredDistanceMeters > 0 || verificationType == QuestVerificationType.walkingGps) {
      final distStr = requiredDistanceMeters >= 1000
          ? '${(requiredDistanceMeters / 1000).toStringAsFixed(1)} km'
          : '${requiredDistanceMeters.round()} m';
      list.add(QuestRequirementModel(
        title: 'Walk $distStr',
        description: 'Cover at least $distStr of outdoor distance',
        requiresCameraProof: false,
        requiresGpsLocation: true,
      ));
    }

    if (requiresDrawing || verificationType == QuestVerificationType.drawingCanvas) {
      final subject = requiredDrawingSubject != null && requiredDrawingSubject.isNotEmpty
          ? requiredDrawingSubject
          : 'the requested scene';
      list.add(QuestRequirementModel(
        title: 'Draw $subject',
        description: 'Create an original sketch on the digital canvas',
        requiresCameraProof: false,
        requiresGpsLocation: false,
      ));
    }

    if (requiresText || verificationType == QuestVerificationType.writingText) {
      final words = requiredWords > 0 ? requiredWords : 100;
      list.add(QuestRequirementModel(
        title: 'Write Journal Log',
        description: 'Compose at least $words words in your explorer logbook',
        requiresCameraProof: false,
        requiresGpsLocation: false,
      ));
    }

    if (requiresPhoto || verificationType == QuestVerificationType.photoProof) {
      final target = requiredObject != null && requiredObject.isNotEmpty
          ? requiredObject
          : 'waypoint';
      list.add(QuestRequirementModel(
        title: 'Capture $target',
        description: 'Take a clear, authentic photograph of a real $target',
        requiresCameraProof: true,
        requiresGpsLocation: requiresGPS,
      ));
    }

    if (requiresVideo || verificationType == QuestVerificationType.timedVideo) {
      final mins = requiredDurationSeconds > 0 ? (requiredDurationSeconds / 60).round() : 10;
      list.add(QuestRequirementModel(
        title: 'Record $mins Min Video Proof',
        description: 'Record an uninterrupted verification video of the activity',
        requiresCameraProof: true,
        requiresGpsLocation: false,
      ));
    }

    if (requiresGameSession || verificationType == QuestVerificationType.gameplayTime) {
      final mins = requiredDurationSeconds > 0 ? (requiredDurationSeconds / 60).round() : 5;
      list.add(QuestRequirementModel(
        title: 'Engage for $mins Minutes',
        description: 'Play and interact with the puzzle activity session',
        requiresCameraProof: false,
        requiresGpsLocation: false,
      ));
    }

    if (list.isEmpty) {
      list.add(const QuestRequirementModel(
        title: 'Complete Quest Objective',
        description: 'Follow the on-screen instructions to verify your adventure',
        requiresCameraProof: false,
        requiresGpsLocation: false,
      ));
    }

    return list;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': id,
      'title': title,
      'description': description,
      'storyline': storyline,
      'category': category.name,
      'difficulty': difficulty.name,
      'verificationType': verificationType.name,
      'repeatability': repeatability.name,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'originLocationName': originLocationName,
      'historicalFact': historicalFact,
      'radiusMeters': radiusMeters,
      'allowedRadius': radiusMeters,
      'xpReward': xpReward,
      'coinReward': coinReward,
      'requiredLevel': requiredLevel,
      'isActive': isActive,
      'active': isActive,
      'isCompleted': isCompleted,
      'requirements': requirements
          .map((r) => QuestRequirementModel(
                title: r.title,
                description: r.description,
                requiresCameraProof: r.requiresCameraProof,
                requiresGpsLocation: r.requiresGpsLocation,
              ).toJson())
          .toList(),
      'iconKey': iconKey,
      'distanceMeters': distanceMeters,
      'placeId': placeId,
      'placeCategory': placeCategory,
      'placeAddress': placeAddress,
      'placeTypes': placeTypes,
      'imageUrl': imageUrl,
      'photoReference': photoReference,
      'photoReferences': photoReferences,
      'photoUrl': photoUrl,
      'imageSource': imageSource,
      'requiredDurationSeconds': requiredDurationSeconds,
      'requiredDistanceMeters': requiredDistanceMeters,
      'requiredWords': requiredWords,
      'requiredLines': requiredLines,
      'requiredRepetitions': requiredRepetitions,
      'requiredObject': requiredObject,
      'requiredPlace': requiredPlace,
      'requiredTarget': requiredTarget,
      'requiredDrawingSubject': requiredDrawingSubject,
      'requiresGPS': requiresGPS,
      'requiresPhoto': requiresPhoto,
      'requiresFreshPhoto': requiresFreshPhoto,
      'requiresVideo': requiresVideo,
      'requiresDrawing': requiresDrawing,
      'requiresText': requiresText,
      'requiresGameSession': requiresGameSession,
      'requiredVerificationRules': requiredVerificationRules,
      'sourceType': sourceType,
      'source_type': sourceType,
      'googlePlaceId': googlePlaceId,
      'google_place_id': googlePlaceId,
      'generationLatitude': generationLatitude,
      'generation_latitude': generationLatitude,
      'generationLongitude': generationLongitude,
      'generation_longitude': generationLongitude,
      'userId': userId,
      'user_id': userId,
    };
  }

  factory QuestModel.fromEntity(Quest entity) {
    return QuestModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      storyline: entity.storyline,
      category: entity.category,
      difficulty: entity.difficulty,
      verificationType: entity.verificationType,
      repeatability: entity.repeatability,
      latitude: entity.latitude,
      longitude: entity.longitude,
      locationName: entity.locationName,
      originLocationName: entity.originLocationName,
      historicalFact: entity.historicalFact,
      radiusMeters: entity.radiusMeters,
      xpReward: entity.xpReward,
      coinReward: entity.coinReward,
      requiredLevel: entity.requiredLevel,
      isActive: entity.isActive,
      isCompleted: entity.isCompleted,
      requirements: entity.requirements,
      iconKey: entity.iconKey,
      distanceMeters: entity.distanceMeters,
      placeId: entity.placeId,
      placeCategory: entity.placeCategory,
      placeAddress: entity.placeAddress,
      placeTypes: entity.placeTypes,
      imageUrl: entity.imageUrl,
      photoReference: entity.photoReference,
      photoReferences: entity.photoReferences,
      photoUrl: entity.photoUrl,
      imageSource: entity.imageSource,
      requiredDurationSeconds: entity.requiredDurationSeconds,
      requiredDistanceMeters: entity.requiredDistanceMeters,
      requiredWords: entity.requiredWords,
      requiredLines: entity.requiredLines,
      requiredRepetitions: entity.requiredRepetitions,
      requiredObject: entity.requiredObject,
      requiredPlace: entity.requiredPlace,
      requiredTarget: entity.requiredTarget,
      requiredDrawingSubject: entity.requiredDrawingSubject,
      requiresGPS: entity.requiresGPS,
      requiresPhoto: entity.requiresPhoto,
      requiresFreshPhoto: entity.requiresFreshPhoto,
      requiresVideo: entity.requiresVideo,
      requiresDrawing: entity.requiresDrawing,
      requiresText: entity.requiresText,
      requiresGameSession: entity.requiresGameSession,
      requiredVerificationRules: entity.requiredVerificationRules,
      sourceType: entity.sourceType,
      googlePlaceId: entity.googlePlaceId,
      generationLatitude: entity.generationLatitude,
      generationLongitude: entity.generationLongitude,
      userId: entity.userId,
    );
  }
}
