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
        title: const Text('Quest Verification'),
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
                      _buildQuestHeader(quest),
                      const SizedBox(height: 14),

                      // Requirements Breakdown Checklist
                      _buildRequirementsChecklist(quest, userCoords),
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

                      // Error message banner if any
                      if (verificationState.errorMessage != null && verificationState.validatorResults.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accentDanger),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.accentDanger),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  verificationState.errorMessage!,
                                  style: AppTypography.bodyMedium.copyWith(color: Colors.white),
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
                  child: CustomButton(
                    text: 'SUBMIT VERIFICATION PROOF',
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

  Widget _buildQuestHeader(Quest quest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
        ],
      ),
    );
  }

  Widget _buildRequirementsChecklist(Quest quest, dynamic userCoords) {
    final items = <Widget>[];

    // GPS Geofence
    if (quest.hasGpsRequirement) {
      items.add(_buildChecklistItem(
        icon: Icons.my_location_rounded,
        title: 'GPS Geofence',
        subtitle: 'Within ${quest.radiusMeters.round()}m of waypoint',
        isMet: userCoords != null &&
            DistanceCalculator.isWithinRadius(
              userLat: userCoords.latitude,
              userLon: userCoords.longitude,
              targetLat: quest.latitude,
              targetLon: quest.longitude,
              radiusMeters: quest.radiusMeters,
            ),
      ));
    }

    // Walking Distance
    if (quest.requiredDistanceMeters > 0 || quest.verificationType == QuestVerificationType.walkingGps) {
      items.add(_buildChecklistItem(
        icon: Icons.directions_walk_rounded,
        title: 'Walking Distance',
        subtitle: '${DistanceCalculator.formatDistance(quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000)} live GPS tracking',
      ));
    }

    // In-App Fresh Photo
    if (quest.requiresFreshPhoto) {
      items.add(_buildChecklistItem(
        icon: Icons.camera_alt_rounded,
        title: 'Fresh In-App Photo',
        subtitle: 'Live camera capture during this quest attempt',
      ));
    } else if (quest.requiresPhoto || quest.verificationType == QuestVerificationType.photoProof) {
      items.add(_buildChecklistItem(
        icon: Icons.photo_camera_outlined,
        title: 'Photo Proof',
        subtitle: 'Capture or upload image proof',
      ));
    }

    // Generic Target Object
    if (quest.hasObjectDetection) {
      items.add(_buildChecklistItem(
        icon: Icons.search_rounded,
        title: 'Target Object',
        subtitle: 'Verify subject contains "${quest.requiredObject}"',
      ));
    }

    // Place Detection
    if (quest.hasPlaceDetection) {
      items.add(_buildChecklistItem(
        icon: Icons.account_balance_outlined,
        title: 'Place / Site',
        subtitle: '${quest.requiredPlace ?? ''} ${quest.requiredTarget ?? ''}'.trim(),
      ));
    }

    // Session Timer
    if (quest.requiredDurationSeconds > 0) {
      items.add(_buildChecklistItem(
        icon: Icons.timer_outlined,
        title: 'Session Duration',
        subtitle: '${(quest.requiredDurationSeconds ~/ 60)} minutes continuous activity',
      ));
    }

    // Word Count
    if (quest.requiredWords > 0) {
      items.add(_buildChecklistItem(
        icon: Icons.edit_note_outlined,
        title: 'Word Count',
        subtitle: 'Minimum ${quest.requiredWords} words written in editor',
      ));
    }

    // Drawing Canvas
    if (quest.requiresDrawing || quest.verificationType == QuestVerificationType.drawingCanvas) {
      items.add(_buildChecklistItem(
        icon: Icons.palette_outlined,
        title: 'Drawing Canvas',
        subtitle: 'Illustrate ${quest.requiredDrawingSubject ?? quest.requiredObject ?? 'artwork'} on canvas',
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
                  ),
                ),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
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
    final allPassed = results.every((r) => r.passed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allPassed ? AppColors.accentSuccess : AppColors.accentDanger,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allPassed ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                color: allPassed ? AppColors.accentSuccess : AppColors.accentDanger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allPassed ? 'Verification Report: All Checks Passed ✅' : 'Verification Report: Requirements Incomplete',
                  style: AppTypography.titleMedium.copyWith(
                    color: allPassed ? AppColors.accentSuccess : AppColors.accentDanger,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.divider),
          ...results.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.passed ? Icons.check_circle : Icons.error_outline,
                      size: 16,
                      color: r.passed ? AppColors.accentSuccess : AppColors.accentDanger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.validatorName}: ${r.actualValue ?? (r.passed ? 'Verified' : 'Failed')}',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            r.message,
                            style: AppTypography.caption.copyWith(
                              color: r.passed ? AppColors.textSecondary : AppColors.accentDanger,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
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
    dynamic userCoords,
  }) {
    switch (quest.verificationType) {
      case QuestVerificationType.drawingCanvas:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Draw Artwork on Canvas', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            DrawingCanvasWidget(
              title: quest.title,
              onDrawingReady: (summary) {
                ref.read(verificationNotifierProvider.notifier).updateDrawingProof(summary);
              },
            ),
          ],
        );

      case QuestVerificationType.writingText:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In-App Writing Editor', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            WritingEditorWidget(
              requiredWords: quest.requiredWords,
              requiredLines: quest.requiredLines,
              promptHint: quest.description,
              onTextChanged: (text, words, isSatisfied) {
                ref.read(verificationNotifierProvider.notifier).updateTextProof(
                      text,
                      words,
                      isSatisfied,
                    );
              },
              onDetailedTextChanged: (text, words, isSatisfied, isAuthentic, pastedChars) {
                ref.read(verificationNotifierProvider.notifier).updateTextProof(
                      text,
                      words,
                      isSatisfied,
                      isPasted: !isAuthentic,
                      pastedChars: pastedChars,
                      isAuthentic: isAuthentic,
                    );
              },
            ),
          ],
        );

      case QuestVerificationType.timedActivity:
      case QuestVerificationType.timedVideo:
      case QuestVerificationType.videoProof:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Timer & Video Proof', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            VideoTimerRecorderWidget(
              requiredDurationSeconds: quest.requiredDurationSeconds,
              requiresVideoProof: quest.requiresVideo,
              cameraService: cameraService,
              onSessionUpdated: (seconds, videoPath, isSatisfied) {
                ref.read(verificationNotifierProvider.notifier).updateSessionTimer(seconds, videoPath, isSatisfied);
              },
            ),
          ],
        );

      case QuestVerificationType.walkingGps:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live GPS Walking Tracker', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            WalkingDistanceTrackerWidget(
              requiredDistanceMeters: quest.requiredDistanceMeters,
              onWalkingUpdated: (dist, isSatisfied) {
                ref.read(verificationNotifierProvider.notifier).updateWalkingDistance(dist, isSatisfied);
              },
            ),
            if (quest.requiresFreshPhoto || quest.requiresPhoto) ...[
              const SizedBox(height: 16),
              Text('Step 2: Landmark Photo Proof', style: AppTypography.titleMedium),
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
              quest.hasGpsRequirement ? 'Step 2: Photo Proof' : 'Photo Proof Submission',
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
