import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Smart Proof Scanner',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Quest Not Found',
                      style: AppTypography.titleLarge.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This quest could not be loaded for verification.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(singleQuestProvider(widget.questId)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final userProfile = ref.watch(userProfileNotifierProvider).valueOrNull;
          final isAlreadyCompleted = quest.isCompleted ||
              (userProfile != null && userProfile.completedQuestIds.contains(quest.id));

          if (isAlreadyCompleted) {
            return _buildAlreadyCompletedView(context, quest);
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
                  Text('Acquiring High-Precision GPS Lock...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // High-Tech Mission Header
                      _buildQuestHeader(quest, verificationState),
                      const SizedBox(height: 14),

                      // Two-Step On-Site Verification Stepper HUD
                      _buildTwoStepVerificationHUD(quest, userCoords, verificationState),

                      // Location Services Prompt if needed
                      if (isLocationRequired && userCoords == null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To verify this quest, enable location services and physically visit ${quest.locationName}.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Premium3DButton(
                                text: 'ENABLE GPS LOCATION',
                                icon: Icons.my_location_rounded,
                                color: AppColors.primary,
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

                      // Anti-Cheat & Requirements Breakdown Checklist
                      _buildRequirementsChecklist(quest, userCoords, verificationState),
                      const SizedBox(height: 16),

                      // Dedicated Verification Engine (Viewfinder, Canvas, Writing, Video, Minigame)
                      _buildVerificationEngine(
                        context,
                        ref,
                        quest: quest,
                        verificationState: verificationState,
                        cameraService: cameraService,
                        userCoords: userCoords,
                      ),
                      const SizedBox(height: 16),

                      // Verification Results / Validation Breakdown
                      if (verificationState.validatorResults.isNotEmpty) ...[
                        _buildVerificationReportCard(verificationState.validatorResults),
                        const SizedBox(height: 16),
                      ],

                      // Rejection Alert Banner if any
                      if (verificationState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.accentDanger, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentDanger.withValues(alpha: 0.2),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cancel_rounded, color: AppColors.accentDanger, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VERIFICATION REJECTED ❌',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.accentDanger,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      verificationState.errorMessage!,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        height: 1.35,
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

              // Bottom Action Launchpad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(top: BorderSide(color: AppColors.borderBright)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: verificationState.uiState == QuestVerificationUIState.rejected
                      ? Row(
                          children: [
                            Expanded(
                              child: Premium3DButton(
                                text: 'RETRY & CAPTURE FRESH PROOF',
                                icon: Icons.refresh_rounded,
                                color: AppColors.accentDanger,
                                onPressed: () {
                                  ref.read(verificationNotifierProvider.notifier).clearProof();
                                },
                              ),
                            ),
                          ],
                        )
                      : Premium3DButton(
                          text: verificationState.isVerifying
                              ? 'VALIDATING TELEMETRY...'
                              : ((quest.requiresPhoto || quest.requiresFreshPhoto || quest.verificationType == QuestVerificationType.photoProof) &&
                                      verificationState.capturedPhotoPath == null
                                  ? 'CAPTURE LIVE PHOTO TO VERIFY'
                                  : 'SUBMIT PROOF FOR VERIFICATION'),
                          icon: (quest.requiresPhoto || quest.requiresFreshPhoto || quest.verificationType == QuestVerificationType.photoProof) &&
                                  verificationState.capturedPhotoPath == null
                              ? Icons.camera_alt_rounded
                              : Icons.verified_rounded,
                          isLoading: verificationState.isVerifying,
                          color: (quest.requiresPhoto || quest.requiresFreshPhoto || quest.verificationType == QuestVerificationType.photoProof) &&
                                  verificationState.capturedPhotoPath == null
                              ? AppColors.secondary
                              : AppColors.primary,
                          width: double.infinity,
                          onPressed: () async {
                            final isPhotoReq = quest.requiresPhoto ||
                                quest.requiresFreshPhoto ||
                                quest.verificationType == QuestVerificationType.photoProof;

                            if (isPhotoReq &&
                                (verificationState.capturedPhotoPath == null ||
                                    verificationState.capturedPhotoPath!.isEmpty)) {
                              // Direct user to live camera capture
                              ref.read(verificationNotifierProvider.notifier).captureCameraProof();
                              return;
                            }

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasActiveSession ? AppColors.primary.withValues(alpha: 0.5) : AppColors.borderBright,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Icon(_getCategoryIcon(quest.category), color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  quest.locationName,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (hasActiveSession)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentSuccess.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentSuccess.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 12, color: AppColors.accentSuccess),
                  const SizedBox(width: 3),
                  Text(
                    'Active',
                    style: AppTypography.badge.copyWith(
                      color: AppColors.accentSuccess,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTwoStepVerificationHUD(
    Quest quest,
    dynamic userCoords,
    VerificationState verificationState,
  ) {
    final hasGps = quest.hasGpsRequirement && quest.latitude != 0.0 && quest.longitude != 0.0;
    final isGpsNearby = !hasGps ||
        (userCoords != null &&
            DistanceCalculator.isWithinRadius(
              userLat: userCoords.latitude,
              userLon: userCoords.longitude,
              targetLat: quest.latitude,
              targetLon: quest.longitude,
              radiusMeters: quest.radiusMeters,
            ));

    final dist = (hasGps && userCoords != null)
        ? DistanceCalculator.calculateDistanceMeters(
            lat1: userCoords.latitude,
            lon1: userCoords.longitude,
            lat2: quest.latitude,
            lon2: quest.longitude,
          )
        : null;

    if (dist != null) {
      debugPrint('[QuestUP Location Quest] Distance to destination: ${dist.round()} m');
    }

    final isPhotoReq = quest.requiresPhoto ||
        quest.requiresFreshPhoto ||
        quest.verificationType == QuestVerificationType.photoProof;

    final hasPhoto = verificationState.capturedPhotoPath != null &&
        verificationState.capturedPhotoPath!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TWO-STEP ON-SITE VERIFICATION PIPELINE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.primary,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step 1: On-Site Geofence Lock
          _buildPipelineStepTile(
            stepNumber: '1',
            title: 'On-Site GPS Geofence Lock',
            subtitle: hasGps
                ? (userCoords == null
                    ? 'Acquiring high-precision GPS position...'
                    : (isGpsNearby
                        ? 'Destination Reached: On-Site position confirmed (${dist?.round()}m from landmark)'
                        : 'Out of Range (${dist?.round()}m away • Need < ${(quest.radiusMeters > 0 ? quest.radiusMeters : 100).round()}m)'))
                : 'GPS Geofence not required for this mission',
            isComplete: isGpsNearby && (hasGps ? userCoords != null : true),
            isAlert: hasGps && userCoords != null && !isGpsNearby,
            activeColor: AppColors.primary,
          ),

          const Padding(
            padding: EdgeInsets.only(left: 17),
            child: SizedBox(
              height: 14,
              child: VerticalDivider(
                color: AppColors.borderBright,
                thickness: 1.5,
              ),
            ),
          ),

          // Step 2: Live On-Site Photo Proof & AI Anti-Cheat Assessment
          _buildPipelineStepTile(
            stepNumber: '2',
            title: 'Live On-Site Proof & Anti-Cheat Scan',
            subtitle: !isGpsNearby
                ? 'Locked: Approach ${quest.locationName} to unlock camera'
                : (hasPhoto
                    ? 'Photo captured (${verificationState.isFreshCapture ? 'Live In-App' : 'Image Attached'}) • Multi-signal anti-cheat active'
                    : (isPhotoReq
                        ? 'Live camera capture required on-site'
                        : 'Input activity telemetry below')),
            isComplete: hasPhoto || (!isPhotoReq && verificationState.isRequirementSatisfied),
            isAlert: isGpsNearby && isPhotoReq && !hasPhoto,
            activeColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStepTile({
    required String stepNumber,
    required String title,
    required String subtitle,
    required bool isComplete,
    required bool isAlert,
    required Color activeColor,
  }) {
    final statusColor = isComplete
        ? AppColors.accentSuccess
        : (isAlert ? AppColors.accentDanger : AppColors.textMuted);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete
                ? AppColors.accentSuccess.withValues(alpha: 0.2)
                : (isAlert
                    ? AppColors.accentDanger.withValues(alpha: 0.2)
                    : AppColors.surfaceElevated),
            border: Border.all(
              color: statusColor,
              width: 1.8,
            ),
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check_rounded, color: AppColors.accentSuccess, size: 18)
                : (isAlert
                    ? const Icon(Icons.close_rounded, color: AppColors.accentDanger, size: 18)
                    : Text(
                        stepNumber,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isComplete ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: isAlert ? AppColors.accentDanger : AppColors.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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
      subtitle: isSessionActive ? 'Active telemetry session' : 'Session expired',
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
        subtitle: 'Within ${quest.radiusMeters.round()}m of landmark',
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
        title: 'Live Camera Capture',
        subtitle: 'Hardware sensor capture required',
        isMet: verificationState.capturedPhotoPath != null && verificationState.isFreshCapture,
      ));
    } else if (quest.requiresPhoto || quest.verificationType == QuestVerificationType.photoProof) {
      items.add(_buildChecklistItem(
        icon: Icons.photo_camera_outlined,
        title: 'Photo Proof',
        subtitle: 'Capture or select verified image',
        isMet: verificationState.capturedPhotoPath != null,
      ));
    }

    // 5. Anti-Duplicate Proof Check
    if (verificationState.mediaHash != null) {
      items.add(_buildChecklistItem(
        icon: Icons.fingerprint_rounded,
        title: 'Anti-Duplicate Hash',
        subtitle: 'SHA-256 fingerprint verified unique',
        isMet: true,
      ));
    }

    // 6. Target Object Detection
    if (quest.hasObjectDetection) {
      items.add(_buildChecklistItem(
        icon: Icons.view_in_ar_rounded,
        title: 'Target Object',
        subtitle: 'Must detect "${quest.requiredObject}"',
      ));
    }

    // 7. Anti-Cheat Screen / Display Check
    if (quest.requiresAntiScreenCheck) {
      items.add(_buildChecklistItem(
        icon: Icons.shield_outlined,
        title: 'Screen Rejection Check',
        subtitle: 'Photos of displays or paper rejected',
        isMet: true,
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
        subtitle: 'Minimum ${quest.requiredWords} words (Anti-paste active)',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VERIFICATION CHECKLIST & ANTI-CHEAT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.primary,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: results.every((r) => r.passed)
              ? AppColors.accentSuccess.withValues(alpha: 0.6)
              : AppColors.accentDanger.withValues(alpha: 0.6),
          width: 1.2,
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
              Expanded(
                child: Text(
                  'Validation Telemetry Breakdown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                ),
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
              quest.hasGpsRequirement ? 'Step 2: Live In-App Camera Scanner' : 'Photo Proof Submission',
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
        return Icons.theater_comedy_rounded;
      case QuestCategory.mystery:
        return Icons.psychology_rounded;
      case QuestCategory.location:
      case QuestCategory.landmark:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildAlreadyCompletedView(BuildContext context, Quest quest) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.accentSuccess.withValues(alpha: 0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentSuccess.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentSuccess.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accentSuccess, width: 2.5),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.accentSuccess,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'MISSION ACCOMPLISHED',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.accentSuccess,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You have already verified and completed "${quest.title}". All XP and Coins have been claimed to your explorer dossier.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderBright),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      '+${quest.xpReward} XP Earned',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.monetization_on_rounded, color: AppColors.secondary, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      '+${quest.coinReward} Coins',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Premium3DButton(
                text: 'RETURN TO QUESTS',
                icon: Icons.arrow_back_rounded,
                color: AppColors.primary,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
