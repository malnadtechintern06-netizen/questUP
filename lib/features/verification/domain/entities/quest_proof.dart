enum ProofVerificationStatus {
  verified,
  rejected,
  reviewRequired,
  pending,
}

class QuestProof {
  final String proofId;
  final String sessionId;
  final String questId;
  final String userId;
  final String proofType; // 'photo', 'video', 'text', 'drawing', 'gps', 'activity'
  final DateTime capturedAt;
  final DateTime submittedAt;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final double? distanceFromTarget;
  final String? mediaReference;
  final String? mediaHash; // SHA-256 fingerprint
  final bool isFreshCameraCapture;
  final bool screenDetection;
  final bool isPhotoOfPhoto;
  final String? sceneContextStatus;
  final ProofVerificationStatus verificationStatus;
  final String? verificationReason;
  final String? contentVerificationStatus; // 'pass', 'fail', 'review_required'
  final Map<String, dynamic> checksPerformed;
  final DateTime createdAt;

  const QuestProof({
    required this.proofId,
    required this.sessionId,
    required this.questId,
    required this.userId,
    required this.proofType,
    required this.capturedAt,
    required this.submittedAt,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.distanceFromTarget,
    this.mediaReference,
    this.mediaHash,
    this.isFreshCameraCapture = true,
    this.screenDetection = false,
    this.isPhotoOfPhoto = false,
    this.sceneContextStatus,
    this.verificationStatus = ProofVerificationStatus.pending,
    this.verificationReason,
    this.contentVerificationStatus,
    this.checksPerformed = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'proofId': proofId,
      'sessionId': sessionId,
      'questId': questId,
      'userId': userId,
      'proofType': proofType,
      'capturedAt': capturedAt.toIso8601String(),
      'submittedAt': submittedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracy': locationAccuracy,
      'distanceFromTarget': distanceFromTarget,
      'mediaReference': mediaReference,
      'mediaHash': mediaHash,
      'isFreshCameraCapture': isFreshCameraCapture,
      'screenDetection': screenDetection,
      'isPhotoOfPhoto': isPhotoOfPhoto,
      'sceneContextStatus': sceneContextStatus,
      'verificationStatus': verificationStatus.name,
      'verificationReason': verificationReason,
      'contentVerificationStatus': contentVerificationStatus,
      'checksPerformed': checksPerformed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QuestProof.fromJson(Map<String, dynamic> json) {
    final statusStr = json['verificationStatus'] as String? ?? 'pending';
    return QuestProof(
      proofId: json['proofId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      questId: json['questId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      proofType: json['proofType'] as String? ?? 'photo',
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? '') ?? DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAccuracy: (json['locationAccuracy'] as num?)?.toDouble(),
      distanceFromTarget: (json['distanceFromTarget'] as num?)?.toDouble(),
      mediaReference: json['mediaReference'] as String?,
      mediaHash: json['mediaHash'] as String?,
      isFreshCameraCapture: json['isFreshCameraCapture'] as bool? ?? true,
      screenDetection: json['screenDetection'] as bool? ?? false,
      isPhotoOfPhoto: json['isPhotoOfPhoto'] as bool? ?? false,
      sceneContextStatus: json['sceneContextStatus'] as String?,
      verificationStatus: ProofVerificationStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => ProofVerificationStatus.pending,
      ),
      verificationReason: json['verificationReason'] as String?,
      contentVerificationStatus: json['contentVerificationStatus'] as String?,
      checksPerformed: json['checksPerformed'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
