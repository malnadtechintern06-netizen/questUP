import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:quest_up/core/services/camera_service.dart';
import 'package:quest_up/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:quest_up/features/calendar/presentation/providers/quest_calendar_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';
import 'package:quest_up/features/verification/data/repositories/verification_repository_impl.dart';
import 'package:quest_up/features/verification/domain/entities/quest_attempt.dart';
import 'package:quest_up/features/verification/domain/entities/quest_completion.dart';
import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';
import 'package:quest_up/features/verification/domain/services/duplicate_proof_service.dart';
import 'package:quest_up/features/verification/domain/services/validators/i_validator.dart';
import 'package:quest_up/features/verification/domain/usecases/get_active_quest_session_usecase.dart';
import 'package:quest_up/features/verification/domain/usecases/get_user_completions_usecase.dart';
import 'package:quest_up/features/verification/domain/usecases/start_quest_session_usecase.dart';
import 'package:quest_up/features/verification/domain/usecases/verify_quest_usecase.dart';

final cameraServiceProvider = Provider<ICameraService>((ref) {
  return CameraService();
});

final verificationLocalDataSourceProvider = Provider<IVerificationLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return VerificationLocalDataSource(storage);
});

final duplicateProofServiceProvider = Provider<IDuplicateProofService>((ref) {
  final localData = ref.watch(verificationLocalDataSourceProvider);
  return DuplicateProofService(localData);
});

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final localData = ref.watch(verificationLocalDataSourceProvider);
  final questRepo = ref.watch(questRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final achievementRepo = ref.watch(achievementRepositoryProvider);
  final calendarRepo = ref.watch(questCalendarRepositoryProvider);
  final duplicateService = ref.watch(duplicateProofServiceProvider);

  return VerificationRepositoryImpl(
    localDataSource: localData,
    questRepository: questRepo,
    userRepository: userRepo,
    achievementRepository: achievementRepo,
    calendarRepository: calendarRepo,
    duplicateProofService: duplicateService,
  );
});

final verifyQuestUseCaseProvider = Provider<VerifyQuestUseCase>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return VerifyQuestUseCase(repo);
});

final startQuestSessionUseCaseProvider = Provider<StartQuestSessionUseCase>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return StartQuestSessionUseCase(repo);
});

final getActiveQuestSessionUseCaseProvider = Provider<GetActiveQuestSessionUseCase>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return GetActiveQuestSessionUseCase(repo);
});

final getUserCompletionsUseCaseProvider = Provider<GetUserCompletionsUseCase>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return GetUserCompletionsUseCase(repo);
});

enum QuestVerificationUIState {
  notStarted,
  inProgress,
  submitting,
  verifying,
  verified,
  rejected,
  retryRequired,
  error,
}

// Verification State
class VerificationState {
  final QuestVerificationUIState uiState;
  final QuestSession? activeSession;
  final QuestAttempt? currentAttempt;
  final String? capturedPhotoPath;
  final bool isFreshCapture;
  final String? mediaHash;
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
    this.uiState = QuestVerificationUIState.notStarted,
    this.activeSession,
    this.currentAttempt,
    this.capturedPhotoPath,
    this.isFreshCapture = false,
    this.mediaHash,
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

  bool get isVerifying =>
      uiState == QuestVerificationUIState.submitting ||
      uiState == QuestVerificationUIState.verifying;

  VerificationState copyWith({
    QuestVerificationUIState? uiState,
    QuestSession? activeSession,
    QuestAttempt? currentAttempt,
    String? capturedPhotoPath,
    bool? isFreshCapture,
    String? mediaHash,
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
      uiState: uiState ?? this.uiState,
      activeSession: activeSession ?? this.activeSession,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      capturedPhotoPath: capturedPhotoPath ?? this.capturedPhotoPath,
      isFreshCapture: isFreshCapture ?? this.isFreshCapture,
      mediaHash: mediaHash ?? this.mediaHash,
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
  final StartQuestSessionUseCase _startSessionUseCase;
  final GetActiveQuestSessionUseCase _getActiveSessionUseCase;
  final IDuplicateProofService _duplicateProofService;
  final ICameraService _cameraService;
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  VerificationNotifier({
    required this._verifyQuestUseCase,
    required this._startSessionUseCase,
    required this._getActiveSessionUseCase,
    required this._duplicateProofService,
    required this._cameraService,
    required this._ref,
  }) : super(const VerificationState());

  Future<void> initAttempt(String questId, String userId) async {
    // Check if an active session already exists for this quest
    final existingSession = await _getActiveSessionUseCase(
      questId: questId,
      userId: userId,
    );

    if (existingSession != null && existingSession.isActive) {
      state = state.copyWith(
        uiState: QuestVerificationUIState.inProgress,
        activeSession: existingSession,
        currentAttempt: QuestAttempt(
          attemptId: existingSession.sessionId,
          userId: userId,
          questId: questId,
          startedAt: existingSession.startedAt,
          freshPhotoToken: 'token_${existingSession.sessionId.substring(0, 8)}',
        ),
      );
    } else {
      final attemptId = _uuid.v4();
      state = state.copyWith(
        uiState: QuestVerificationUIState.notStarted,
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

  Future<QuestSession> startQuestSession({
    required String questId,
    required String userId,
    double? startingLat,
    double? startingLon,
    String? proofType,
  }) async {
    final session = await _startSessionUseCase(
      questId: questId,
      userId: userId,
      startingLat: startingLat,
      startingLon: startingLon,
      requiredProofType: proofType,
    );

    state = state.copyWith(
      uiState: QuestVerificationUIState.inProgress,
      activeSession: session,
      currentAttempt: QuestAttempt(
        attemptId: session.sessionId,
        userId: userId,
        questId: questId,
        startedAt: session.startedAt,
        freshPhotoToken: 'token_${session.sessionId.substring(0, 8)}',
      ),
    );

    return session;
  }

  Future<void> captureCameraProof() async {
    final photo = await _cameraService.takePhoto();
    if (photo != null) {
      final hash = await _duplicateProofService.computeFileHash(photo);
      state = state.copyWith(
        capturedPhotoPath: photo,
        isFreshCapture: true,
        mediaHash: hash,
        isRequirementSatisfied: true,
      );
    }
  }

  Future<void> pickProofFromGallery() async {
    final photo = await _cameraService.pickFromGallery();
    if (photo != null) {
      final hash = await _duplicateProofService.computeFileHash(photo);
      state = state.copyWith(
        capturedPhotoPath: photo,
        isFreshCapture: false,
        mediaHash: hash,
        isRequirementSatisfied: true,
      );
    }
  }

  Future<void> recordVideoProof({Duration? maxDuration}) async {
    final video = await _cameraService.recordVideo(maxDuration: maxDuration);
    if (video != null) {
      final hash = await _duplicateProofService.computeFileHash(video);
      state = state.copyWith(
        capturedVideoPath: video,
        mediaHash: hash,
      );
    }
  }

  void updateDrawingProof(String summary) {
    final hash = _duplicateProofService.computeContentHash(summary);
    state = state.copyWith(
      drawingProofSummary: summary,
      mediaHash: hash,
      isRequirementSatisfied: true,
    );
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
    final hash = _duplicateProofService.computeContentHash(text);
    state = state.copyWith(
      textContent: text,
      mediaHash: hash,
      wordCount: words,
      lineCount: lines,
      isRequirementSatisfied: isSatisfied,
      isPasted: false,
      pastedCharactersCount: 0,
      isAuthenticallyTyped: true,
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
    state = state.copyWith(
      capturedPhotoPath: null,
      capturedVideoPath: null,
      drawingProofSummary: null,
      textContent: null,
      mediaHash: null,
      isFreshCapture: false,
      isRequirementSatisfied: false,
      validatorResults: const [],
      errorMessage: null,
      uiState: state.activeSession != null
          ? QuestVerificationUIState.inProgress
          : QuestVerificationUIState.notStarted,
    );
  }

  Future<VerificationResult> submitVerification({
    required Quest quest,
    double? userLat,
    double? userLon,
  }) async {
    final isPhotoRequired = quest.requiresPhoto ||
        quest.requiresFreshPhoto ||
        quest.verificationType == QuestVerificationType.photoProof;

    if (isPhotoRequired &&
        (state.capturedPhotoPath == null || state.capturedPhotoPath!.trim().isEmpty)) {
      final failResult = VerificationResult(
        isSuccessful: false,
        message:
            'Photo Proof Required: Please snap a photo using the QuestUP live camera before submitting verification.',
        isGpsValid: userLat != null && userLon != null,
        isCameraValid: false,
        validatorResults: const [
          ValidatorResult(
            passed: false,
            validatorName: 'Fresh In-App Photo Proof',
            actualValue: 'No photo provided',
            requiredValue: 'Live In-App Camera Capture',
            message:
                'Photo Proof Required: Please capture a live photo on-site using the in-app camera.',
          ),
        ],
      );
      state = state.copyWith(
        uiState: QuestVerificationUIState.rejected,
        errorMessage: failResult.message,
        result: failResult,
        validatorResults: failResult.validatorResults,
      );
      return failResult;
    }

    state = state.copyWith(
      uiState: QuestVerificationUIState.verifying,
      errorMessage: null,
    );

    try {
      final attempt = state.currentAttempt ??
          QuestAttempt(
            attemptId: state.activeSession?.sessionId ?? _uuid.v4(),
            userId: 'player',
            questId: quest.id,
            startedAt: state.activeSession?.startedAt ?? DateTime.now(),
          );

      final photoPath = state.capturedPhotoPath;

      String? effectiveHash = state.mediaHash;
      if (effectiveHash == null && photoPath != null) {
        effectiveHash = await _duplicateProofService.computeFileHash(photoPath);
      }

      final payload = VerificationProofPayload(
        userLat: userLat,
        userLon: userLon,
        photoProofPath: photoPath,
        isFreshCameraCapture: state.isFreshCapture ||
            (photoPath != null &&
                (photoPath.contains('camera_capture_') || photoPath.contains('fresh_proof_'))),
        photoAttemptId: attempt.attemptId,
        sessionId: state.activeSession?.sessionId,
        questSession: state.activeSession,
        mediaHash: effectiveHash,
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
        sessionId: state.activeSession?.sessionId,
        userLat: userLat,
        userLon: userLon,
        photoProofPath: photoPath,
        videoProofPath: state.capturedVideoPath,
        drawingProofSummary: state.drawingProofSummary,
        textContent: state.textContent,
        wordCount: state.wordCount,
        durationSeconds: state.durationSeconds,
        distanceMeters: state.distanceMeters,
        mediaHash: effectiveHash,
      );

      state = state.copyWith(
        uiState: result.isSuccessful
            ? QuestVerificationUIState.verified
            : QuestVerificationUIState.rejected,
        result: result,
        validatorResults: result.validatorResults,
        errorMessage: result.isSuccessful ? null : result.message,
      );

      if (result.isSuccessful) {
        // Refresh related state notifiers
        await _ref.read(questsNotifierProvider.notifier).fetchQuests();
        await _ref.read(userProfileNotifierProvider.notifier).loadProfile();
        await _ref.read(achievementsNotifierProvider.notifier).loadAchievements();
        await _ref.read(questCalendarNotifierProvider.notifier).refresh();
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
        uiState: QuestVerificationUIState.error,
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
  final startSessionUseCase = ref.watch(startQuestSessionUseCaseProvider);
  final getActiveSessionUseCase = ref.watch(getActiveQuestSessionUseCaseProvider);
  final duplicateService = ref.watch(duplicateProofServiceProvider);
  final cameraService = ref.watch(cameraServiceProvider);

  return VerificationNotifier(
    verifyQuestUseCase: verifyUseCase,
    startSessionUseCase: startSessionUseCase,
    getActiveSessionUseCase: getActiveSessionUseCase,
    duplicateProofService: duplicateService,
    cameraService: cameraService,
    ref: ref,
  );
});
