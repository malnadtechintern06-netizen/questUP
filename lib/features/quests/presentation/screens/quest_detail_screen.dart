import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/maps_launcher_service.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';
import 'package:quest_up/core/widgets/quest_rarity_badge.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/quests/presentation/widgets/google_maps_marker_card_widget.dart';

class QuestDetailScreen extends ConsumerWidget {
  final String questId;

  const QuestDetailScreen({
    super.key,
    required this.questId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questAsync = ref.watch(singleQuestProvider(questId));
    final activeGps = ref.watch(activeGpsCoordinatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: questAsync.when(
        loading: () => const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 0),
          ),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: ErrorStateWidget(
            message: 'Mission briefing not found.',
            onRetry: () => ref.refresh(singleQuestProvider(questId)),
          ),
        ),
        data: (quest) {
          if (quest == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Center(
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
                        'This quest could not be loaded. Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(singleQuestProvider(questId)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          double? liveDistance;
          if (activeGps != null && quest.latitude != 0.0 && quest.longitude != 0.0) {
            liveDistance = DistanceCalculator.calculateDistanceMeters(
              lat1: activeGps.latitude,
              lon1: activeGps.longitude,
              lat2: quest.latitude,
              lon2: quest.longitude,
            );
            debugPrint('[QuestUP Location Quest] Distance to destination: ${liveDistance.round()} m');
          }
          final effectiveDistance = liveDistance ?? quest.distanceMeters ?? 0.0;
          final isWithinRadius = (quest.latitude == 0.0 && quest.longitude == 0.0) ||
              (effectiveDistance <= (quest.radiusMeters > 0 ? quest.radiusMeters : 100.0));
          final distStr = DistanceCalculator.formatDistance(effectiveDistance);

          return Stack(
            children: [
              // Scrollable Mission Dossier
              CustomScrollView(
                slivers: [
                  // 1. Holographic 3D Header
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    backgroundColor: AppColors.background,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                          onPressed: () {
                            ref.read(mapsLauncherServiceProvider).openGoogleMapsLocation(
                                  quest.latitude,
                                  quest.longitude,
                                  label: quest.locationName,
                                );
                          },
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          GoogleMapsMarkerCardWidget(
                            quest: quest,
                            height: 280,
                            width: double.infinity,
                          ),
                          // Dark gradient overlay for dossier contrast
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.background.withValues(alpha: 0.7),
                                  AppColors.background,
                                ],
                                stops: const [0.3, 0.75, 1.0],
                              ),
                            ),
                          ),
                          // Rarity & Status Pill Overlays
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 24,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                QuestRarityBadge.fromDifficulty(quest.difficulty),
                                if (quest.isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentSuccess.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.accentSuccess),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            size: 13, color: AppColors.accentSuccess),
                                        const SizedBox(width: 4),
                                        Text(
                                          'COMPLETED',
                                          style: AppTypography.badge.copyWith(
                                            color: AppColors.accentSuccess,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isWithinRadius)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentSuccess.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.accentSuccess),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on_rounded,
                                            size: 13, color: AppColors.accentSuccess),
                                        const SizedBox(width: 4),
                                        Text(
                                          'DESTINATION REACHED',
                                          style: AppTypography.badge.copyWith(
                                            color: AppColors.accentSuccess,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        ],
                      ),
                    ),
                  ),

                  // 2. Mission Dossier Body
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mission Title
                          Text(
                            quest.title,
                            style: AppTypography.displayLarge.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Location Subtitle with Distance
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  quest.locationName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  distStr,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 3. Rewards Vault Card
                          _buildRewardsVaultCard(quest),

                          const SizedBox(height: 20),

                          // 4. Mission Briefing Section
                          _buildSectionTitle('MISSION BRIEFING', Icons.article_rounded),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              quest.description,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 5. Verification Protocol & Anti-Cheat Requirements
                          _buildSectionTitle('VERIFICATION PROTOCOLS', Icons.security_rounded),
                          const SizedBox(height: 8),
                          _buildVerificationProtocolsCard(quest),

                          const SizedBox(height: 20),

                          // 6. Tactical Navigation & Landmark Launcher
                          _buildSectionTitle('TACTICAL LOCATION', Icons.map_rounded),
                          const SizedBox(height: 8),
                          _buildLocationNavigationCard(context, ref, quest, activeGps),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 7. Sticky 3D Launchpad Action Button at Bottom
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Premium3DButton(
                    text: quest.isCompleted
                        ? 'MISSION ACCOMPLISHED'
                        : (isWithinRadius ? 'START VERIFICATION (DESTINATION REACHED)' : 'APPROACH LOCATION & VERIFY'),
                    icon: quest.isCompleted
                        ? Icons.verified_rounded
                        : (isWithinRadius ? Icons.check_circle_rounded : Icons.near_me_rounded),
                    color: quest.isCompleted
                        ? AppColors.accentSuccess
                        : (isWithinRadius ? AppColors.primary : AppColors.secondary),
                    onPressed: () {
                      if (quest.isCompleted) {
                        _showAlreadyCompletedDialog(context, quest);
                      } else {
                        context.push(RoutePaths.questVerifyPath(quest.id));
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.badge.copyWith(
              color: AppColors.primary,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardsVaultCard(Quest quest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF162035),
            Color(0xFF0F1523),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'MISSION REWARDS VAULT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // XP Reward Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accentXp.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.accentXp.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.accentXp),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+${quest.xpReward} XP',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.accentXp,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Rank Boost',
                                style: AppTypography.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Coins Reward Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monetization_on_rounded,
                            size: 18, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+${quest.coinReward} Coins',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Store Currency',
                                style: AppTypography.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationProtocolsCard(Quest quest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildProtocolItem(
            icon: Icons.satellite_alt_rounded,
            title: 'GPS Geofence Proximity',
            desc: 'Must be within ${quest.radiusMeters.round()}m of landmark.',
            isPassed: quest.isWithinAllowedRadius,
          ),
          const Divider(color: AppColors.divider, height: 20),
          _buildProtocolItem(
            icon: Icons.camera_alt_rounded,
            title: 'Live Camera Capture',
            desc: quest.requiresFreshPhoto
                ? 'Direct hardware capture required. Gallery uploads blocked.'
                : 'Verified visual proof required.',
            isPassed: true,
          ),
          if (quest.hasObjectDetection) ...[
            const Divider(color: AppColors.divider, height: 20),
            _buildProtocolItem(
              icon: Icons.view_in_ar_rounded,
              title: 'Object Recognition Target',
              desc: 'Target required: ${quest.requiredObject!.toUpperCase()}',
              isPassed: true,
            ),
          ],
          const Divider(color: AppColors.divider, height: 20),
          _buildProtocolItem(
            icon: Icons.fingerprint_rounded,
            title: 'Anti-Cheat Hash & Integrity',
            desc: 'SHA-256 duplicate image rejection & screen-rejection checks enabled.',
            isPassed: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isPassed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPassed ? AppColors.primaryLight : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: isPassed ? AppColors.primary : AppColors.textMuted),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationNavigationCard(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
    dynamic activeGps,
  ) {
    final hasCoordinates = quest.latitude != 0.0 && quest.longitude != 0.0;
    final userCoords = activeGps;
    final distanceMeters = (hasCoordinates && userCoords != null)
        ? DistanceCalculator.calculateDistanceMeters(
            lat1: userCoords.latitude,
            lon1: userCoords.longitude,
            lat2: quest.latitude,
            lon2: quest.longitude,
          )
        : quest.distanceMeters;

    final distStr = distanceMeters != null
        ? DistanceCalculator.formatDistance(distanceMeters)
        : 'Calculating...';

    final isWithinRadius = (distanceMeters != null && distanceMeters <= quest.radiusMeters);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROUTE & DESTINATION DISPATCH',
                      style: AppTypography.badge.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'GPS Telemetry & Waypoint Navigation',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isWithinRadius
                      ? AppColors.accentSuccess.withValues(alpha: 0.15)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWithinRadius ? AppColors.accentSuccess : AppColors.primary,
                  ),
                ),
                child: Text(
                  isWithinRadius ? 'IN RANGE (~${quest.radiusMeters.round()}m)' : distStr,
                  style: AppTypography.badge.copyWith(
                    color: isWithinRadius ? AppColors.accentSuccess : AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route Visualizer: Origin to Destination
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Origin: Current Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.accentSuccess,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentSuccess.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT LOCATION (ORIGIN)',
                            style: AppTypography.caption.copyWith(
                              fontSize: 9.5,
                              color: AppColors.accentSuccess,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userCoords != null
                                ? 'GPS: ${userCoords.latitude.toStringAsFixed(4)}°, ${userCoords.longitude.toStringAsFixed(4)}°'
                                : 'Acquiring GPS position...',
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Connecting Dotted Line & Distance Indicator
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.borderBright,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_walk_rounded, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Distance: $distStr',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Destination: Target Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA4335), // Google Maps Pin Red
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA4335).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DESTINATION LOCATION (TARGET)',
                            style: AppTypography.caption.copyWith(
                              fontSize: 9.5,
                              color: const Color(0xFFEA4335),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quest.locationName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (hasCoordinates) ...[
                            const SizedBox(height: 1),
                            Text(
                              'GPS: ${quest.latitude.toStringAsFixed(4)}°, ${quest.longitude.toStringAsFixed(4)}°',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Open in Google Maps & Live Walking Route
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(mapsLauncherServiceProvider).openGoogleMapsLocation(
                          quest.latitude,
                          quest.longitude,
                          label: quest.locationName,
                        );
                  },
                  icon: const Icon(Icons.map_rounded, size: 16, color: AppColors.primary),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'GOOGLE MAPS',
                      style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 10),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(mapsLauncherServiceProvider).openGoogleMapsDirections(
                          originLat: activeGps?.latitude ?? quest.latitude,
                          originLon: activeGps?.longitude ?? quest.longitude,
                          destLat: quest.latitude,
                          destLon: quest.longitude,
                          destinationName: quest.locationName,
                        );
                  },
                  icon: const Icon(Icons.directions_walk_rounded,
                      size: 16, color: AppColors.secondary),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'WALKING ROUTE',
                      style: AppTypography.badge.copyWith(color: AppColors.secondary, fontSize: 10),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    side: const BorderSide(color: AppColors.secondary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAlreadyCompletedDialog(BuildContext context, Quest quest) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accentSuccess.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentSuccess.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentSuccess.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accentSuccess, width: 2),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.accentSuccess,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'MISSION ACCOMPLISHED',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.accentSuccess,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You have already conquered "${quest.title}" and claimed all rewards. No further verification is needed.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderBright),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '+${quest.xpReward} XP',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Icon(Icons.monetization_on_rounded, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 4),
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
              const SizedBox(height: 24),
              Premium3DButton(
                text: 'RETURN TO QUESTS',
                icon: Icons.arrow_back_rounded,
                color: AppColors.primary,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
