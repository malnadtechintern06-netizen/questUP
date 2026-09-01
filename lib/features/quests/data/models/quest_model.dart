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
  });

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    final questId = (json['id'] ?? json['questId'] ?? '').toString();
    final radius = (json['radiusMeters'] ?? json['allowedRadius'] as num?)?.toDouble() ?? 75.0;
    final active = (json['isActive'] ?? json['active'] as bool?) ?? true;

    final catStr = json['category'] as String? ?? 'landmark';
    final category = QuestCategory.values.firstWhere(
      (e) => e.name == catStr,
      orElse: () => QuestCategory.landmark,
    );

    final verTypeStr = json['verificationType'] as String? ?? 'locationGps';
    final verificationType = QuestVerificationType.values.firstWhere(
      (e) => e.name == verTypeStr,
      orElse: () {
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

    final repStr = json['repeatability'] as String? ?? 'oneTime';
    final repeatability = QuestRepeatability.values.firstWhere(
      (e) => e.name == repStr,
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

    final photoUrlVal = json['photoUrl'] as String? ?? json['imageUrl'] as String?;
    final photoRefVal = json['photoReference'] as String? ?? json['photo_reference'] as String?;
    final imgSource = json['imageSource'] as String? ??
        (photoRefVal != null && photoRefVal.isNotEmpty ? 'google_places' : 'fallback');

    return QuestModel(
      id: questId,
      title: json['title'] as String? ?? 'Exploration Waypoint',
      description: json['description'] as String? ?? '',
      storyline: json['storyline'] as String? ?? (json['description'] as String? ?? ''),
      category: category,
      difficulty: QuestDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => QuestDifficulty.easy,
      ),
      verificationType: verificationType,
      repeatability: repeatability,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationName: json['locationName'] as String? ?? 'Local Waypoint',
      originLocationName: json['originLocationName'] as String?,
      historicalFact: json['historicalFact'] as String?,
      radiusMeters: radius,
      xpReward: json['xpReward'] as int? ?? 100,
      coinReward: json['coinReward'] as int? ?? 50,
      requiredLevel: json['requiredLevel'] as int? ?? 1,
      isActive: active,
      isCompleted: json['isCompleted'] as bool? ?? false,
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => QuestRequirementModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [
            const QuestRequirementModel(
              title: 'Reach GPS Location',
              description: 'Travel within the target coordinates radius',
            ),
            const QuestRequirementModel(
              title: 'Snap Photo Proof',
              description: 'Take a clear photograph of the waypoint',
            ),
          ],
      iconKey: json['iconKey'] as String? ?? 'landmark',
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      placeId: json['placeId'] as String?,
      placeCategory: json['placeCategory'] as String?,
      placeAddress: json['placeAddress'] as String? ?? json['address'] as String?,
      placeTypes: pTypes,
      imageUrl: photoUrlVal,
      photoReference: photoRefVal,
      photoReferences: pRefs,
      photoUrl: photoUrlVal,
      imageSource: imgSource,
      requiredDurationSeconds: json['requiredDurationSeconds'] as int? ?? 0,
      requiredDistanceMeters:
          (json['requiredDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      requiredWords: json['requiredWords'] as int? ?? 0,
      requiredLines: json['requiredLines'] as int? ?? 0,
      requiredRepetitions: json['requiredRepetitions'] as int? ?? 0,
      requiredObject: json['requiredObject'] as String?,
      requiredPlace: json['requiredPlace'] as String?,
      requiredTarget: json['requiredTarget'] as String?,
      requiredDrawingSubject: json['requiredDrawingSubject'] as String?,
      requiresGPS: json['requiresGPS'] as bool? ?? false,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      requiresFreshPhoto: json['requiresFreshPhoto'] as bool? ?? false,
      requiresVideo: json['requiresVideo'] as bool? ?? false,
      requiresDrawing: json['requiresDrawing'] as bool? ?? false,
      requiresText: json['requiresText'] as bool? ?? false,
      requiresGameSession: json['requiresGameSession'] as bool? ?? false,
      requiredVerificationRules: rulesList,
    );
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
    );
  }
}
