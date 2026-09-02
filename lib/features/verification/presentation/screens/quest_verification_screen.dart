import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/custom_button.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/reward_dialog.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/location_permission/presentation/providers/location_permission_provider.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/verification/domain/entities/validator_result.dart';
import 'package:quest_up/features/verification/presentation/providers/verification_providers.dart';
import 'package:quest_up/features/verification/presentation/widgets/camera_proof_viewfinder.dart';
import 'package:quest_up/features/verification/presentation/widgets/drawing_canvas_widget.dart';
import 'package:quest_up/features/verification/presentation/widgets/gps_proximity_badge.dart';
import 'package:quest_up/features/verification/presentation/widgets/in_app_game_tracker_widget.dart';
import 'package:quest_up/features/verification/presentation/widgets/video_timer_recorder_widget.dart';
import 'package:quest_up/features/verification/presentation/widgets/walking_distance_tracker_widget.dart';
import 'package:quest_up/features/verification/presentation/widgets/writing_editor_widget.dart';

class QuestVerificationScreen extends ConsumerStatefulWidget {
  final String questId;

  const QuestVerificationScreen({
    super.key,
    required this.questId,
  });

  @override
  ConsumerState<QuestVerificationScreen> createState() => _QuestVerificationScreenState();
}

class _QuestVerificationScreenState extends ConsumerState<QuestVerificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = ref.read(userProfileNotifierProvider).valueOrNull;
      ref.read(verificationNotifierProvider.notifier).initAttempt(
            widget.questId,
            userProfile?.id ?? 'player',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final questAsync = ref.watch(singleQuestProvider(widget.questId));
    final locationAsync = ref.watch(currentLocationProvider);
    final verificationState = ref.watch(verificationNotifierProvider);
    final cameraService = ref.watch(cameraServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Proof Verification'),
      ),
      body: questAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              ShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
              SizedBox(height: 16),
              ShimmerBox(width: double.infinity, height: 160, borderRadius: 16),
            ],
          ),
        ),
        error: (err, _) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.refresh(singleQuestProvider(widget.questId)),
        ),
        data: (quest) {
          if (quest == null) {
            return const Center(child: Text('Quest not found'));
          }

          final isLocationRequired = quest.hasGpsRequirement ||
              quest.verificationType == QuestVerificationType.locationGps ||
              quest.verificationType == QuestVerificationType.walkingGps;

          final userCoords = locationAsync.valueOrNull;

          if (isLocationRequired && userCoords == null && locationAsync.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Acquiring GPS Satellite Signal...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quest Header Card
                      _buildQuestHeader(quest, verificationState),
                      const SizedBox(height: 14),

                      // Location Services & Proximity Check Prompt
                      if (isLocationRequired && userCoords == null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.accentDanger.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_off_rounded, color: AppColors.accentDanger, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Location Services Disabled',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.accentDanger,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To complete this quest, open the app, enable location services, and physically visit ${quest.locationName}.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CustomButton(
                                text: 'ENABLE LOCATION / GPS',
                                icon: Icons.my_location_rounded,
                                customColor: AppColors.primary,
                                width: double.infinity,
                                onPressed: () {
                                  ref
                                      .read(locationPermissionNotifierProvider.notifier)
                                      .requestAndAcquireLocation();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Requirements Breakdown Checklist
                      _buildRequirementsChecklist(quest, userCoords, verificationState),
                      const SizedBox(height: 16),

                      // Dedicated Verification Engine
                      _buildVerificationEngine(
                        context,
                        ref,
                        quest: quest,
                        verificationState: verificationState,
                        cameraService: cameraService,
                        userCoords: userCoords,
                      ),
                      const SizedBox(height: 16),

                      // Verification Results / Report Card
                      if (verificationState.validatorResults.isNotEmpty) ...[
                        _buildVerificationReportCard(verificationState.validatorResults),
                        const SizedBox(height: 16),
                      ],

                      // Error / Rejection message banner if any
                      if (verificationState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.accentDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.accentDanger),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cancel_rounded, color: AppColors.accentDanger, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PROOF REJECTED ❌',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.accentDanger,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      verificationState.errorMessage!,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action CTA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: SafeArea(
                  child: verificationState.uiState == QuestVerificationUIState.rejected
                      ? Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'RETRY & CAPTURE FRESH PROOF',
                                icon: Icons.refresh_rounded,
                                customColor: AppColors.accentDanger,
                                onPressed: () {
                                  ref.read(verificationNotifierProvider.notifier).clearProof();
                                },
                              ),
                            ),
                          ],
                        )
                      : CustomButton(
                          text: verificationState.isVerifying
                              ? 'VERIFYING PROOF... ⏳'
                              : 'SUBMIT PROOF FOR VERIFICATION',
                          icon: Icons.verified_rounded,
                          isLoading: verificationState.isVerifying,
                          width: double.infinity,
                          onPressed: () async {
                            final result = await ref
                                .read(verificationNotifierProvider.notifier)
                                .submitVerification(
                                  quest: quest,
                                  userLat: userCoords?.latitude,
                                  userLon: userCoords?.longitude,
                                );

                            if (result.isSuccessful && context.mounted) {
                              RewardDialog.show(
                                context,
                                questTitle: quest.title,
                                xpEarned: result.xpEarned,
                                coinsEarned: result.coinsEarned,
                                didLevelUp: result.didLevelUp,
                                newLevel: result.newLevel,
                                unlockedBadgeTitle: result.unlockedBadgeTitle,
                                onClaim: () {
                                  context.go(RoutePaths.home);
                                },
                              );
                            }
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestHeader(Quest quest, VerificationState state) {
    final hasActiveSession = state.activeSession != null && state.activeSession!.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveSession ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getCategoryIcon(quest.category), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: AppTypography.titleMedium,
                    ),
                    Text(
                      quest.locationName,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (hasActiveSession)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentSuccess.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentSuccess.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 12, color: AppColors.accentSuccess),
                      const SizedBox(width: 3),
                      Text(
                        'Session Active',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentSuccess,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsChecklist(
    Quest quest,
    dynamic userCoords,
    VerificationState verificationState,
  ) {
    final items = <Widget>[];

    // 1. Quest Session Status
    final isSessionActive = verificationState.activeSession?.isActive ?? true;
    items.add(_buildChecklistItem(
      icon: Icons.shield_outlined,
      title: 'Quest Session',
      subtitle: isSessionActive ? 'Active quest session' : 'Session expired',
      isMet: isSessionActive,
    ));

    // 2. GPS Geofence
    if (quest.hasGpsRequirement) {
      final isGpsNearby = userCoords != null &&
          DistanceCalculator.isWithinRadius(
            userLat: userCoords.latitude,
            userLon: userCoords.longitude,
            targetLat: quest.latitude,
            targetLon: quest.longitude,
            radiusMeters: quest.radiusMeters,
          );

      items.add(_buildChecklistItem(
        icon: Icons.my_location_rounded,
        title: 'GPS Geofence',
        subtitle: 'Within ${quest.radiusMeters.round()}m of waypoint',
        isMet: userCoords != null ? isGpsNearby : null,
      ));
    }

    // 3. Walking Distance
    if (quest.requiredDistanceMeters > 0 || quest.verificationType == QuestVerificationType.walkingGps) {
      items.add(_buildChecklistItem(
        icon: Icons.directions_walk_rounded,
        title: 'Walking Distance',
        subtitle: '${DistanceCalculator.formatDistance(quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000)} live GPS tracking',
        isMet: verificationState.distanceMeters >= (quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000),
      ));
    }

    // 4. In-App Fresh Photo
    if (quest.requiresFreshPhoto) {
      items.add(_buildChecklistItem(
        icon: Icons.camera_alt_rounded,
        title: 'Fresh In-App Photo',
        subtitle: 'Live camera capture during this session',
        isMet: verificationState.capturedPhotoPath != null && verificationState.isFreshCapture,
      ));
    } else if (quest.requiresPhoto || quest.verificationType == QuestVerificationType.photoProof) {
      items.add(_buildChecklistItem(
        icon: Icons.photo_camera_outlined,
        title: 'Photo Proof',
        subtitle: 'Capture or upload image proof',
        isMet: verificationState.capturedPhotoPath != null,
      ));
    }

    // 5. Anti-Duplicate Proof Check
    if (verificationState.mediaHash != null) {
      items.add(_buildChecklistItem(
        icon: Icons.fingerprint_rounded,
        title: 'Anti-Duplicate Check',
        subtitle: 'Unique SHA-256 fingerprint verified',
        isMet: true,
      ));
    }

    // 6. Generic Target Object
    if (quest.hasObjectDetection) {
      items.add(_buildChecklistItem(
        icon: Icons.search_rounded,
        title: 'Target Object',
        subtitle: 'Verify subject contains "${quest.requiredObject}"',
      ));
    }

    // 7. Anti-Cheat Screen / Display Check
    if (quest.requiresAntiScreenCheck) {
      items.add(_buildChecklistItem(
        icon: Icons.shield_outlined,
        title: 'Anti-Screen & Display Check',
        subtitle: 'Photos of screens, monitors, or posters rejected',
        isMet: true,
      ));
    }

    // 7. Place Detection
    if (quest.hasPlaceDetection) {
      items.add(_buildChecklistItem(
        icon: Icons.account_balance_outlined,
        title: 'Place / Site',
        subtitle: '${quest.requiredPlace ?? ''} ${quest.requiredTarget ?? ''}'.trim(),
      ));
    }

    // 8. Session Timer / Video
    if (quest.requiredDurationSeconds > 0) {
      items.add(_buildChecklistItem(
        icon: Icons.timer_outlined,
        title: 'Session Duration',
        subtitle: '${(quest.requiredDurationSeconds ~/ 60)} mins continuous session',
        isMet: verificationState.durationSeconds >= quest.requiredDurationSeconds,
      ));
    }

    // 9. Word Count & Anti-Cheat
    if (quest.requiredWords > 0) {
      items.add(_buildChecklistItem(
        icon: Icons.edit_note_outlined,
        title: 'Word Count',
        subtitle: 'Minimum ${quest.requiredWords} words (Anti-cheat typing enabled)',
        isMet: verificationState.wordCount >= quest.requiredWords && !verificationState.isPasted,
      ));
    }

    // 10. Drawing Canvas
    if (quest.requiresDrawing || quest.verificationType == QuestVerificationType.drawingCanvas) {
      items.add(_buildChecklistItem(
        icon: Icons.palette_outlined,
        title: 'Drawing Canvas',
        subtitle: 'Illustrate ${quest.requiredDrawingSubject ?? quest.requiredObject ?? 'artwork'} on canvas',
        isMet: verificationState.drawingProofSummary != null,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Verification Requirements Checklist',
                style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool? isMet,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet == true
                ? Icons.check_circle_rounded
                : (isMet == false ? Icons.cancel_rounded : icon),
            size: 16,
            color: isMet == true
                ? AppColors.accentSuccess
                : (isMet == false ? AppColors.accentDanger : AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$title: ',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationReportCard(List<ValidatorResult> results) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: results.every((r) => r.passed)
              ? AppColors.accentSuccess.withValues(alpha: 0.5)
              : AppColors.accentDanger.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                results.every((r) => r.passed)
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: results.every((r) => r.passed)
                    ? AppColors.accentSuccess
                    : AppColors.accentDanger,
              ),
              const SizedBox(width: 8),
              Text(
                'Smart Proof Validation Breakdown',
                style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...results.map((r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r.passed ? Icons.check_rounded : Icons.close_rounded,
                    color: r.passed ? AppColors.accentSuccess : AppColors.accentDanger,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.validatorName,
                          style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          r.message,
                          style: AppTypography.caption.copyWith(
                            color: r.passed ? AppColors.textSecondary : AppColors.accentDanger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVerificationEngine(
    BuildContext context,
    WidgetRef ref, {
    required Quest quest,
    required VerificationState verificationState,
    required dynamic cameraService,
    required dynamic userCoords,
  }) {
    switch (quest.verificationType) {
      case QuestVerificationType.walkingGps:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Walking Tracker Proof', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            WalkingDistanceTrackerWidget(
              requiredDistanceMeters: quest.requiredDistanceMeters > 0
                  ? quest.requiredDistanceMeters
                  : 1000.0,
              onWalkingUpdated: (dist, isSatisfied) {
                ref
                    .read(verificationNotifierProvider.notifier)
                    .updateWalkingDistance(dist, isSatisfied);
              },
            ),
          ],
        );

      case QuestVerificationType.timedVideo:
      case QuestVerificationType.videoProof:
      case QuestVerificationType.timedActivity:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Continuous Activity Video Verification', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            VideoTimerRecorderWidget(
              requiredDurationSeconds: quest.requiredDurationSeconds > 0
                  ? quest.requiredDurationSeconds
                  : 300,
              requiresVideoProof: quest.requiresVideo ||
                  quest.verificationType == QuestVerificationType.timedVideo,
              cameraService: cameraService,
              onSessionUpdated: (seconds, videoPath, isSatisfied) {
                ref
                    .read(verificationNotifierProvider.notifier)
                    .updateSessionTimer(seconds, videoPath, isSatisfied);
              },
            ),
          ],
        );

      case QuestVerificationType.writingText:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Authentic Writing Challenge', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            WritingEditorWidget(
              requiredWords: quest.requiredWords > 0 ? quest.requiredWords : 50,
              promptHint: quest.description,
              onTextChanged: (text, count, isSatisfied) {
                ref.read(verificationNotifierProvider.notifier).updateTextProof(
                      text,
                      count,
                      isSatisfied,
                    );
              },
              onDetailedTextChanged: (text, count, isSatisfied, isAuthentic, pastedChars) {
                ref.read(verificationNotifierProvider.notifier).updateTextProof(
                      text,
                      count,
                      isSatisfied,
                      isPasted: !isAuthentic,
                      pastedChars: pastedChars,
                      isAuthentic: isAuthentic,
                    );
              },
            ),
          ],
        );

      case QuestVerificationType.drawingCanvas:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Drawing Canvas Challenge', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            DrawingCanvasWidget(
              title: quest.requiredDrawingSubject ?? quest.requiredObject ?? 'Artwork',
              onDrawingReady: (summary) {
                ref.read(verificationNotifierProvider.notifier).updateDrawingProof(summary);
              },
            ),
          ],
        );

      case QuestVerificationType.gameplayTime:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In-App Interactive Game Challenge', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            InAppGameTrackerWidget(
              targetPlayTimeSeconds: quest.requiredDurationSeconds > 0 ? quest.requiredDurationSeconds : 180,
              onGameSessionUpdated: (seconds, moves, isSatisfied) {
                ref.read(verificationNotifierProvider.notifier).updateGameSession(seconds, moves, isSatisfied);
              },
            ),
          ],
        );

      case QuestVerificationType.locationGps:
      case QuestVerificationType.photoProof:
      case QuestVerificationType.compositeRules:
      case QuestVerificationType.customConfig:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quest.hasGpsRequirement && userCoords != null) ...[
              Text('Step 1: Geofence Verification', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              GpsProximityBadge(
                userLat: userCoords.latitude,
                userLon: userCoords.longitude,
                targetLat: quest.latitude,
                targetLon: quest.longitude,
                radiusMeters: quest.radiusMeters,
              ),
              const SizedBox(height: 20),
            ],
            Text(
              quest.hasGpsRequirement ? 'Step 2: In-App Photo Proof' : 'Photo Proof Submission',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            CameraProofViewfinder(
              photoPath: verificationState.capturedPhotoPath,
              requiresFreshPhoto: quest.requiresFreshPhoto,
              requiredObject: quest.requiredObject,
              requiredPlace: quest.requiredPlace,
              onTakePhoto: () {
                ref.read(verificationNotifierProvider.notifier).captureCameraProof();
              },
              onPickGallery: () {
                ref.read(verificationNotifierProvider.notifier).pickProofFromGallery();
              },
              onClear: () {
                ref.read(verificationNotifierProvider.notifier).clearProof();
              },
            ),
          ],
        );
    }
  }

  IconData _getCategoryIcon(QuestCategory category) {
    switch (category) {
      case QuestCategory.reading:
        return Icons.menu_book_rounded;
      case QuestCategory.writing:
        return Icons.edit_note_rounded;
      case QuestCategory.drawing:
        return Icons.palette_rounded;
      case QuestCategory.exercise:
      case QuestCategory.fitness:
        return Icons.fitness_center_rounded;
      case QuestCategory.gaming:
        return Icons.sports_esports_rounded;
      case QuestCategory.food:
        return Icons.restaurant_rounded;
      case QuestCategory.walking:
        return Icons.directions_walk_rounded;
      case QuestCategory.nature:
        return Icons.forest_rounded;
      case QuestCategory.observation:
        return Icons.search_rounded;
      case QuestCategory.study:
        return Icons.school_rounded;
      case QuestCategory.photo:
        return Icons.photo_camera_rounded;
      case QuestCategory.video:
        return Icons.videocam_rounded;
      case QuestCategory.timed:
        return Icons.timer_rounded;
      case QuestCategory.custom:
        return Icons.tune_rounded;
      case QuestCategory.culture:
        return Icons.theater_comedy_outlined;
      case QuestCategory.mystery:
        return Icons.psychology_alt_outlined;
      case QuestCategory.location:
      case QuestCategory.landmark:
        return Icons.account_balance_rounded;
    }
  }
}
