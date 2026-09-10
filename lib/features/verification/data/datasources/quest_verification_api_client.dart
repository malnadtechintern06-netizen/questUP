import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../app/config/mysql_config.dart';

class QuestVerificationStartResponse {
  final bool success;
  final String message;
  final String attemptId;
  final String challengeToken;
  final String questId;
  final String verificationType;
  final int expiresInSeconds;
  final Map<String, dynamic> requirements;
  final bool isDuplicate;

  const QuestVerificationStartResponse({
    required this.success,
    required this.message,
    this.attemptId = '',
    this.challengeToken = '',
    this.questId = '',
    this.verificationType = 'locationGps',
    this.expiresInSeconds = 900,
    this.requirements = const {},
    this.isDuplicate = false,
  });

  factory QuestVerificationStartResponse.fromJson(Map<String, dynamic> json) {
    return QuestVerificationStartResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      attemptId: json['attempt_id'] as String? ?? '',
      challengeToken: json['challenge_token'] as String? ?? '',
      questId: json['quest_id'] as String? ?? '',
      verificationType: json['verification_type'] as String? ?? 'locationGps',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 900,
      requirements: json['requirements'] as Map<String, dynamic>? ?? const {},
      isDuplicate: json['is_duplicate'] as bool? ?? false,
    );
  }
}

class PhotoProofUploadResponse {
  final bool success;
  final String message;
  final String attemptId;
  final String mediaUrl;
  final String imageHash;
  final String perceptualHash;

  const PhotoProofUploadResponse({
    required this.success,
    required this.message,
    this.attemptId = '',
    this.mediaUrl = '',
    this.imageHash = '',
    this.perceptualHash = '',
  });

  factory PhotoProofUploadResponse.fromJson(Map<String, dynamic> json) {
    return PhotoProofUploadResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      attemptId: json['attempt_id'] as String? ?? '',
      mediaUrl: json['media_url'] as String? ?? '',
      imageHash: json['image_hash'] as String? ?? '',
      perceptualHash: json['perceptual_hash'] as String? ?? '',
    );
  }
}

class ServerVerificationResult {
  final bool success;
  final String status; // 'verified', 'pending_admin', 'rejected'
  final String message;
  final String completionId;
  final String attemptId;
  final int xpEarned;
  final int coinsEarned;
  final bool didLevelUp;
  final int newLevel;
  final bool isDuplicate;
  final bool isPendingAdminReview;
  final String? locationResult;

  const ServerVerificationResult({
    required this.success,
    this.status = 'rejected',
    required this.message,
    this.completionId = '',
    this.attemptId = '',
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.didLevelUp = false,
    this.newLevel = 1,
    this.isDuplicate = false,
    this.isPendingAdminReview = false,
    this.locationResult,
  });

  factory ServerVerificationResult.fromJson(Map<String, dynamic> json) {
    final statusVal = json['status'] as String? ?? (json['success'] == true ? 'verified' : 'rejected');
    return ServerVerificationResult(
      success: json['success'] as bool? ?? false,
      status: statusVal,
      message: json['message'] as String? ?? (json['success'] == true ? 'Quest verified successfully!' : 'Verification failed'),
      completionId: json['completion_id'] as String? ?? '',
      attemptId: json['attempt_id'] as String? ?? '',
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      didLevelUp: json['did_level_up'] as bool? ?? false,
      newLevel: (json['new_level'] as num?)?.toInt() ?? 1,
      isDuplicate: json['is_duplicate'] as bool? ?? false,
      isPendingAdminReview: json['is_pending_review'] as bool? ?? (statusVal == 'pending_admin' || statusVal == 'pending'),
      locationResult: json['location_result'] as String?,
    );
  }
}

abstract class IQuestVerificationApiClient {
  Future<QuestVerificationStartResponse> startVerification({
    required String questId,
    required String userId,
    String? deviceId,
    String? deviceInfo,
  });

  Future<PhotoProofUploadResponse> uploadPhotoProof({
    required String attemptId,
    required String userId,
    required String photoFilePath,
    DateTime? clientCaptureTime,
  });

  Future<ServerVerificationResult> verifyQuest({
    required String attemptId,
    required String challengeToken,
    required String questId,
    required String userId,
    Map<String, dynamic>? proofPayload,
    double? latitude,
    double? longitude,
    String? deviceId,
  });

  Future<Map<String, dynamic>> checkVerificationStatus({
    required String userId,
    String? attemptId,
    String? questId,
  });
}

class QuestVerificationApiClient implements IQuestVerificationApiClient {
  static final QuestVerificationApiClient instance = QuestVerificationApiClient();

  String _workingBaseUrl = '';

  List<String> get _candidateBaseUrls {
    final list = <String>[];
    if (_workingBaseUrl.isNotEmpty) {
      list.add(_workingBaseUrl);
    }
    for (final u in MySqlConfig.apiBaseUrls) {
      if (u != _workingBaseUrl) list.add(u);
    }
    return list;
  }

  @override
  Future<QuestVerificationStartResponse> startVerification({
    required String questId,
    required String userId,
    String? deviceId,
    String? deviceInfo,
  }) async {
    final payload = jsonEncode({
      'quest_id': questId,
      'user_id': userId,
      'device_id': deviceId ?? 'android_client',
      'device_info': deviceInfo ?? Platform.operatingSystem,
    });

    for (final base in _candidateBaseUrls) {
      final urlStr = '$base/quests/start_verification.php';
      HttpClient? client;
      try {
        final uri = Uri.parse(urlStr);
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 4)
          ..badCertificateCallback = ((cert, host, port) => true);

        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/json; charset=utf-8');
        request.headers.set('Accept', 'application/json');
        request.write(payload);

        final response = await request.close().timeout(const Duration(seconds: 5));
        final bodyStr = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(bodyStr) as Map<String, dynamic>;

        _workingBaseUrl = base;
        return QuestVerificationStartResponse.fromJson(jsonMap);
      } catch (e) {
        debugPrint('[VerificationApiClient] startVerification failed on $urlStr: $e');
      } finally {
        client?.close();
      }
    }

    return const QuestVerificationStartResponse(
      success: false,
      message: 'Could not connect to QuestUP verification server. Please check your network connection.',
    );
  }

  @override
  Future<PhotoProofUploadResponse> uploadPhotoProof({
    required String attemptId,
    required String userId,
    required String photoFilePath,
    DateTime? clientCaptureTime,
  }) async {
    final file = File(photoFilePath);
    if (!await file.exists()) {
      return const PhotoProofUploadResponse(
        success: false,
        message: 'Camera capture photo file not found on device.',
      );
    }

    final bytes = await file.readAsBytes();
    final boundary = '----QuestUpBoundary${DateTime.now().millisecondsSinceEpoch}';

    for (final base in _candidateBaseUrls) {
      final urlStr = '$base/quests/upload_proof.php';
      HttpClient? client;
      try {
        final uri = Uri.parse(urlStr);
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6)
          ..badCertificateCallback = ((cert, host, port) => true);

        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

        final body = <int>[];
        void addField(String name, String value) {
          body.addAll(utf8.encode('--$boundary\r\n'));
          body.addAll(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
          body.addAll(utf8.encode('$value\r\n'));
        }

        addField('attempt_id', attemptId);
        addField('user_id', userId);
        if (clientCaptureTime != null) {
          addField('client_capture_time', clientCaptureTime.toIso8601String());
        }

        body.addAll(utf8.encode('--$boundary\r\n'));
        body.addAll(utf8.encode('Content-Disposition: form-data; name="image"; filename="photo.jpg"\r\n'));
        body.addAll(utf8.encode('Content-Type: image/jpeg\r\n\r\n'));
        body.addAll(bytes);
        body.addAll(utf8.encode('\r\n'));
        body.addAll(utf8.encode('--$boundary--\r\n'));

        request.add(body);
        final response = await request.close().timeout(const Duration(seconds: 8));
        final bodyStr = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(bodyStr) as Map<String, dynamic>;

        _workingBaseUrl = base;
        return PhotoProofUploadResponse.fromJson(jsonMap);
      } catch (e) {
        debugPrint('[VerificationApiClient] uploadPhotoProof failed on $urlStr: $e');
      } finally {
        client?.close();
      }
    }

    return const PhotoProofUploadResponse(
      success: false,
      message: 'Failed to upload photo proof to server.',
    );
  }

  @override
  Future<ServerVerificationResult> verifyQuest({
    required String attemptId,
    required String challengeToken,
    required String questId,
    required String userId,
    Map<String, dynamic>? proofPayload,
    double? latitude,
    double? longitude,
    String? deviceId,
  }) async {
    final payload = jsonEncode({
      'attempt_id': attemptId,
      'challenge_token': challengeToken,
      'quest_id': questId,
      'user_id': userId,
      'proof_payload': proofPayload ?? {},
      'latitude': latitude,
      'longitude': longitude,
      'device_id': deviceId ?? 'android_client',
    });

    for (final base in _candidateBaseUrls) {
      final urlStr = '$base/quests/verify.php';
      HttpClient? client;
      try {
        final uri = Uri.parse(urlStr);
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5)
          ..badCertificateCallback = ((cert, host, port) => true);

        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/json; charset=utf-8');
        request.headers.set('Accept', 'application/json');
        request.write(payload);

        final response = await request.close().timeout(const Duration(seconds: 7));
        final bodyStr = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(bodyStr) as Map<String, dynamic>;

        _workingBaseUrl = base;
        return ServerVerificationResult.fromJson(jsonMap);
      } catch (e) {
        debugPrint('[VerificationApiClient] verifyQuest failed on $urlStr: $e');
      } finally {
        client?.close();
      }
    }

    return const ServerVerificationResult(
      success: false,
      status: 'error',
      message: 'Verification server communication error. Please try again.',
    );
  }

  @override
  Future<Map<String, dynamic>> checkVerificationStatus({
    required String userId,
    String? attemptId,
    String? questId,
  }) async {
    for (final base in _candidateBaseUrls) {
      final uriStr = '$base/quests/verification_status.php?user_id=${Uri.encodeComponent(userId)}'
          '${attemptId != null ? '&attempt_id=${Uri.encodeComponent(attemptId)}' : ''}'
          '${questId != null ? '&quest_id=${Uri.encodeComponent(questId)}' : ''}';
      HttpClient? client;
      try {
        final uri = Uri.parse(uriStr);
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 4)
          ..badCertificateCallback = ((cert, host, port) => true);

        final request = await client.getUrl(uri);
        request.headers.set('Accept', 'application/json');

        final response = await request.close().timeout(const Duration(seconds: 5));
        final bodyStr = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(bodyStr) as Map<String, dynamic>;

        _workingBaseUrl = base;
        return jsonMap;
      } catch (e) {
        debugPrint('[VerificationApiClient] checkVerificationStatus failed on $uriStr: $e');
      } finally {
        client?.close();
      }
    }
    return {'success': false, 'status': 'unknown'};
  }
}
