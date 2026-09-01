import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/maps_launcher_service.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/custom_button.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/quests/presentation/widgets/quest_image_widget.dart';

class QuestDetailScreen extends ConsumerWidget {
  final String questId;

  const QuestDetailScreen({
    super.key,
    required this.questId,
  });

  Color _getDifficultyColor(QuestDifficulty diff) {
    switch (diff) {
      case QuestDifficulty.easy:
        return AppColors.difficultyEasy;
      case QuestDifficulty.medium:
        return AppColors.difficultyMedium;
      case QuestDifficulty.hard:
        return AppColors.difficultyHard;
      case QuestDifficulty.legendary:
        return AppColors.difficultyLegendary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questAsync = ref.watch(singleQuestProvider(questId));
    final userProfileAsync = ref.watch(userProfileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Dossier'),
      ),
      body: questAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              ShimmerBox(width: double.infinity, height: 180, borderRadius: 20),
              SizedBox(height: 20),
              ShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
            ],
          ),
        ),
        error: (err, stack) => ErrorStateWidget(
          message: 'Error loading quest details: $err',
          onRetry: () => ref.refresh(singleQuestProvider(questId)),
        ),
        data: (quest) {
          if (quest == null) {
            return ErrorStateWidget(
              message: 'Quest not found.',
              onRetry: () => ref.refresh(singleQuestProvider(questId)),
            );
          }

          final diffColor = _getDifficultyColor(quest.difficulty);
          final userLevel = userProfileAsync.valueOrNull?.level ?? 1;
          final isLocked = userLevel < quest.requiredLevel;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            QuestImageWidget(
                              quest: quest,
                              height: 150,
                              width: double.infinity,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              fit: BoxFit.cover,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: diffColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: diffColor.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          quest.difficulty.name.toUpperCase(),
                                          style: AppTypography.badge.copyWith(color: diffColor),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          quest.category.name.toUpperCase(),
                                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (quest.distanceMeters != null)
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.near_me, size: 14, color: AppColors.accentLocation),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  DistanceCalculator.formatDistance(quest.distanceMeters!),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: AppTypography.caption.copyWith(
                                                    color: AppColors.accentLocation,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    quest.title,
                                    style: AppTypography.displayMedium.copyWith(fontSize: 22),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.pin_drop_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          quest.locationName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Level Lock Warning (if applicable)
                      if (isLocked) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.accentDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.accentDanger),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_clock_rounded, color: AppColors.accentDanger),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Requires Level ${quest.requiredLevel} to unlock. Level up by completing other nearby quests!',
                                  style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Rewards Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildRewardItem(
                                icon: Icons.bolt_rounded,
                                color: AppColors.accentXp,
                                value: '+${quest.xpReward} XP',
                                label: 'Experience',
                              ),
                            ),
                            Container(width: 1, height: 40, color: AppColors.divider),
                            Expanded(
                              child: _buildRewardItem(
                                icon: Icons.monetization_on_rounded,
                                color: AppColors.secondary,
                                value: '+${quest.coinReward} Coins',
                                label: 'Bounty',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Origin & Destination Connection Journey
                      if (quest.originLocationName != null) ...[
                        Text('Exploration Corridor', style: AppTypography.titleMedium),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF192A3A),
                                AppColors.surface,
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentLocation.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.my_location, color: AppColors.accentLocation, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('ORIGIN POINT', style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10)),
                                        Text(
                                          quest.originLocationName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium.copyWith(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 15, top: 4, bottom: 4),
                                child: Container(
                                  width: 2,
                                  height: 20,
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.account_balance, color: AppColors.primary, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('IMPORTANT LANDMARK', style: AppTypography.caption.copyWith(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                        Text(
                                          quest.locationName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium.copyWith(fontSize: 14, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (quest.historicalFact != null) ...[
                                const Divider(color: AppColors.divider, height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.secondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        quest.historicalFact!,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 14),
                              CustomButton(
                                text: 'Navigate in Google Maps',
                                icon: Icons.directions_walk_rounded,
                                isOutlined: true,
                                width: double.infinity,
                                onPressed: () {
                                  final userGps = ref.read(activeGpsCoordinatesProvider);
                                  ref.read(mapsLauncherServiceProvider).openGoogleMapsDirections(
                                        originLat: userGps?.latitude ?? quest.latitude,
                                        originLon: userGps?.longitude ?? quest.longitude,
                                        destLat: quest.latitude,
                                        destLon: quest.longitude,
                                        destinationName: quest.locationName,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Storyline & Description
                      Text('Quest Storyline', style: AppTypography.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.storyline.isNotEmpty ? quest.storyline : quest.description,
                              style: AppTypography.bodyLarge.copyWith(height: 1.5),
                            ),
                            if (quest.latitude != 0.0 && quest.longitude != 0.0) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Target GPS: ${quest.latitude.toStringAsFixed(4)}, ${quest.longitude.toStringAsFixed(4)} (Geofence: ${quest.radiusMeters.round()}m)',
                                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      ref.read(mapsLauncherServiceProvider).openGoogleMapsLocation(
                                            quest.latitude,
                                            quest.longitude,
                                            label: quest.locationName,
                                          );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.map_outlined, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Google Maps',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (quest.hasObjectDetection) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.search_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Target Object: Find & photograph "${quest.requiredObject}" ${quest.requiresFreshPhoto ? '(Live In-App Camera Only)' : ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (quest.requiresDrawing) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.palette_outlined, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Drawing Target: Illustrate ${quest.requiredDrawingSubject ?? 'artwork'} on canvas',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (quest.requiredDurationSeconds > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Session Goal: ${(quest.requiredDurationSeconds ~/ 60)} minutes continuous activity',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (quest.requiredWords > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.edit_note_outlined, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Writing Goal: Minimum ${quest.requiredWords} words in in-app editor',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (quest.requiredDistanceMeters > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.directions_walk_outlined, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Walking Goal: ${DistanceCalculator.formatDistance(quest.requiredDistanceMeters)} tracked live via GPS',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Requirements List
                      Text('Verification Requirements', style: AppTypography.titleMedium),
                      const SizedBox(height: 8),
                      ...quest.requirements.map((req) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  req.requiresCameraProof
                                      ? Icons.camera_alt_outlined
                                      : Icons.pin_drop_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.title,
                                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      req.description,
                                      style: AppTypography.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: SafeArea(
                  child: quest.isCompleted
                      ? Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'QUEST COMPLETED & REWARDED',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : CustomButton(
                          text: isLocked ? 'LOCKED (LEVEL ${quest.requiredLevel})' : 'START & VERIFY QUEST',
                          icon: isLocked ? Icons.lock : Icons.explore,
                          width: double.infinity,
                          onPressed: isLocked
                              ? null
                              : () {
                                  context.push(RoutePaths.questVerifyPath(quest.id));
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

  Widget _buildRewardItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption,
        ),
      ],
    );
  }
}
