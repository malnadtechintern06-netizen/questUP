import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:quest_up/core/services/camera_service.dart';
import 'package:quest_up/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';
import 'package:quest_up/features/verification/data/repositories/verification_repository_impl.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';
import 'package:quest_up/features/verification/domain/usecases/get_user_completions_usecase.dart';
import 'package:quest_up/features/verification/domain/usecases/verify_quest_usecase.dart';

final cameraServiceProvider = Provider<ICameraService>((ref) {
  return CameraService();
});

final verificationLocalDataSourceProvider = Provider<IVerificationLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return VerificationLocalDataSource(storage);
});

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final localData = ref.watch(verificationLocalDataSourceProvider);
  final questRepo = ref.watch(questRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final achievementRepo = ref.watch(achievementRepositoryProvider);

  return VerificationRepositoryImpl(
    localDataSource: localData,
    questRepository: questRepo,
    userRepository: userRepo,
    achievementRepository: achievementRepo,
  );
});

final verifyQuestUseCaseProvider = Provider<VerifyQuestUseCase>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return VerifyQuestUseCase(repo);
});

final getUserCompletionsUseCaseProvider = Provider<GetUserCompletionsUseCase>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return GetUserCompletionsUseCase(repo);
});

// Verification State
class VerificationState {
  final bool isVerifying;
  final QuestAttempt? currentAttempt;
  final String? capturedPhotoPath;
  final bool isFreshCapture;
  final String? capturedVideoPath;
  final String? drawingProofSummary;
  final String? textContent;
  final int wordCount;
  final int lineCount;
  final int durationSeconds;
  final double distanceMeters;
  final bool isRequirementSatisfied;
  final bool isPasted;
  final int pastedCharactersCount;
  final bool isAuthenticallyTyped;
  final VerificationResult? result;
  final List<ValidatorResult> validatorResults;
  final String? errorMessage;

  const VerificationState({
    this.isVerifying = false,
    this.currentAttempt,
    this.capturedPhotoPath,
    this.isFreshCapture = false,
    this.capturedVideoPath,
    this.drawingProofSummary,
    this.textContent,
    this.wordCount = 0,
    this.lineCount = 0,
    this.durationSeconds = 0,
    this.distanceMeters = 0.0,
    this.isRequirementSatisfied = false,
    this.isPasted = false,
    this.pastedCharactersCount = 0,
    this.isAuthenticallyTyped = true,
    this.result,
    this.validatorResults = const [],
    this.errorMessage,
  });

  VerificationState copyWith({
    bool? isVerifying,
    QuestAttempt? currentAttempt,
    String? capturedPhotoPath,
    bool? isFreshCapture,
    String? capturedVideoPath,
    String? drawingProofSummary,
    String? textContent,
    int? wordCount,
    int? lineCount,
    int? durationSeconds,
    double? distanceMeters,
    bool? isRequirementSatisfied,
    bool? isPasted,
    int? pastedCharactersCount,
    bool? isAuthenticallyTyped,
    VerificationResult? result,
    List<ValidatorResult>? validatorResults,
    String? errorMessage,
  }) {
    return VerificationState(
      isVerifying: isVerifying ?? this.isVerifying,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      capturedPhotoPath: capturedPhotoPath ?? this.capturedPhotoPath,
      isFreshCapture: isFreshCapture ?? this.isFreshCapture,
      capturedVideoPath: capturedVideoPath ?? this.capturedVideoPath,
      drawingProofSummary: drawingProofSummary ?? this.drawingProofSummary,
      textContent: textContent ?? this.textContent,
      wordCount: wordCount ?? this.wordCount,
      lineCount: lineCount ?? this.lineCount,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isRequirementSatisfied: isRequirementSatisfied ?? this.isRequirementSatisfied,
      isPasted: isPasted ?? this.isPasted,
      pastedCharactersCount: pastedCharactersCount ?? this.pastedCharactersCount,
      isAuthenticallyTyped: isAuthenticallyTyped ?? this.isAuthenticallyTyped,
      result: result ?? this.result,
      validatorResults: validatorResults ?? this.validatorResults,
      errorMessage: errorMessage,
    );
  }
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  final VerifyQuestUseCase _verifyQuestUseCase;
  final ICameraService _cameraService;
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  VerificationNotifier(
    this._verifyQuestUseCase,
    this._cameraService,
    this._ref,
  ) : super(const VerificationState());

  void initAttempt(String questId, String userId) {
    if (state.currentAttempt == null || state.currentAttempt!.questId != questId) {
      final attemptId = _uuid.v4();
      state = state.copyWith(
        currentAttempt: QuestAttempt(
          attemptId: attemptId,
          userId: userId,
          questId: questId,
          startedAt: DateTime.now(),
          freshPhotoToken: 'token_${attemptId.substring(0, 8)}',
        ),
      );
    }
  }

  Future<void> captureCameraProof() async {
    final photo = await _cameraService.takePhoto();
    if (photo != null) {
      state = state.copyWith(
        capturedPhotoPath: photo,
        isFreshCapture: true,
        isRequirementSatisfied: true,
      );
    }
  }

  Future<void> pickProofFromGallery() async {
    final photo = await _cameraService.pickFromGallery();
    if (photo != null) {
      state = state.copyWith(
        capturedPhotoPath: photo,
        isFreshCapture: false,
        isRequirementSatisfied: true,
      );
    }
  }

  Future<void> recordVideoProof({Duration? maxDuration}) async {
    final video = await _cameraService.recordVideo(maxDuration: maxDuration);
    if (video != null) {
      state = state.copyWith(capturedVideoPath: video);
    }
  }

  void updateDrawingProof(String summary) {
    state = state.copyWith(drawingProofSummary: summary, isRequirementSatisfied: true);
  }

  void updateTextProof(
    String text,
    int words,
    bool isSatisfied, {
    bool isPasted = false,
    int pastedChars = 0,
    bool isAuthentic = true,
  }) {
    final lines = text.isEmpty ? 0 : text.split('\n').length;
    state = state.copyWith(
      textContent: text,
      wordCount: words,
      lineCount: lines,
      isRequirementSatisfied: isSatisfied && !isPasted && isAuthentic,
      isPasted: isPasted,
      pastedCharactersCount: pastedChars,
      isAuthenticallyTyped: isAuthentic,
    );
  }

  void updateSessionTimer(int seconds, String? videoPath, bool isSatisfied) {
    state = state.copyWith(
      durationSeconds: seconds,
      capturedVideoPath: videoPath ?? state.capturedVideoPath,
      isRequirementSatisfied: isSatisfied,
    );
  }

  void updateWalkingDistance(double distanceMeters, bool isSatisfied) {
    state = state.copyWith(
      distanceMeters: distanceMeters,
      isRequirementSatisfied: isSatisfied,
    );
  }

  void updateGameSession(int playTimeSeconds, int moves, bool isSatisfied) {
    state = state.copyWith(
      durationSeconds: playTimeSeconds,
      isRequirementSatisfied: isSatisfied,
    );
  }

  void clearProof() {
    state = const VerificationState();
  }

  Future<VerificationResult> submitVerification({
    required Quest quest,
    double? userLat,
    double? userLon,
  }) async {
    state = state.copyWith(isVerifying: true, errorMessage: null);

    try {
      final attempt = state.currentAttempt ??
          QuestAttempt(
            attemptId: _uuid.v4(),
            userId: 'player',
            questId: quest.id,
            startedAt: DateTime.now(),
          );

      final photoPath = state.capturedPhotoPath ??
          (quest.requiresPhoto || quest.requiresFreshPhoto
              ? 'camera_capture_${quest.requiredObject ?? 'proof'}_${DateTime.now().millisecondsSinceEpoch}.jpg'
              : null);

      final payload = VerificationProofPayload(
        userLat: userLat,
        userLon: userLon,
        photoProofPath: photoPath,
        isFreshCameraCapture: state.isFreshCapture || (photoPath != null && photoPath.contains('camera_capture_')),
        photoAttemptId: attempt.attemptId,
        videoProofPath: state.capturedVideoPath,
        durationSeconds: state.durationSeconds,
        textContent: state.textContent,
        wordCount: state.wordCount,
        lineCount: state.lineCount,
        drawingProofSummary: state.drawingProofSummary,
        distanceMeters: state.distanceMeters,
        gameplaySeconds: state.durationSeconds,
        isPasted: state.isPasted,
        pastedCharactersCount: state.pastedCharactersCount,
        isAuthenticallyTyped: state.isAuthenticallyTyped,
      );

      final result = await _verifyQuestUseCase(
        quest: quest,
        attempt: attempt,
        payload: payload,
        userLat: userLat,
        userLon: userLon,
        photoProofPath: photoPath,
        videoProofPath: state.capturedVideoPath,
        drawingProofSummary: state.drawingProofSummary,
        textContent: state.textContent,
        wordCount: state.wordCount,
        durationSeconds: state.durationSeconds,
        distanceMeters: state.distanceMeters,
      );

      state = state.copyWith(
        isVerifying: false,
        result: result,
        validatorResults: result.validatorResults,
        errorMessage: result.isSuccessful ? null : result.message,
      );

      if (result.isSuccessful) {
        // Refresh related state notifiers
        await _ref.read(questsNotifierProvider.notifier).fetchQuests();
        await _ref.read(userProfileNotifierProvider.notifier).loadProfile();
        await _ref.read(achievementsNotifierProvider.notifier).loadAchievements();
      }

      return result;
    } catch (e) {
      final failResult = VerificationResult(
        isSuccessful: false,
        message: e.toString(),
        isGpsValid: false,
        isCameraValid: false,
      );
      state = state.copyWith(
        isVerifying: false,
        errorMessage: e.toString(),
        result: failResult,
      );
      return failResult;
    }
  }
}

final verificationNotifierProvider =
    StateNotifierProvider.autoDispose<VerificationNotifier, VerificationState>((ref) {
  final verifyUseCase = ref.watch(verifyQuestUseCaseProvider);
  final cameraService = ref.watch(cameraServiceProvider);
  return VerificationNotifier(verifyUseCase, cameraService, ref);
});
