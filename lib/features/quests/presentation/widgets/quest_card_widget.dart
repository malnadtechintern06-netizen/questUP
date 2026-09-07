import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../../../core/widgets/quest_rarity_badge.dart';
import '../../domain/entities/quest.dart';

class QuestCardWidget extends StatelessWidget {
  final Quest quest;
  final VoidCallback onTap;

  const QuestCardWidget({
    super.key,
    required this.quest,
    required this.onTap,
  });

  Color _getRarityColor(Quest quest) {
    if (quest.isCompleted) return AppColors.accentSuccess;
    switch (quest.difficulty) {
      case QuestDifficulty.easy:
        return AppColors.rarityUncommon;
      case QuestDifficulty.medium:
        return AppColors.rarityRare;
      case QuestDifficulty.hard:
        return AppColors.rarityEpic;
      case QuestDifficulty.legendary:
        return AppColors.rarityLegendary;
    }
  }

  IconData _getCategoryIcon(QuestCategory cat) {
    switch (cat) {
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

  String _getVerificationBadgeText(Quest quest) {
    if (quest.hasObjectDetection) {
      final obj = quest.requiredObject!;
      final prefix = obj == 'flower'
          ? '🌸'
          : obj == 'cow'
              ? '🐄'
              : obj == 'tree'
                  ? '🌳'
                  : obj == 'apple'
                      ? '🍎'
                      : obj == 'book'
                          ? '📖'
                          : obj == 'bicycle'
                              ? '🚲'
                              : '🔍';
      return '$prefix ${obj[0].toUpperCase()}${obj.substring(1)}';
    }

    switch (quest.verificationType) {
      case QuestVerificationType.drawingCanvas:
        return '🎨 ${quest.requiredDrawingSubject != null ? quest.requiredDrawingSubject![0].toUpperCase() + quest.requiredDrawingSubject!.substring(1) : 'Canvas'}';
      case QuestVerificationType.writingText:
        return '✍️ ${quest.requiredWords > 0 ? '${quest.requiredWords}w' : 'Writing'}';
      case QuestVerificationType.timedActivity:
      case QuestVerificationType.timedVideo:
      case QuestVerificationType.videoProof:
        final mins = (quest.requiredDurationSeconds ~/ 60);
        return '⏱ ${mins > 0 ? '${mins}m' : 'Timed'}';
      case QuestVerificationType.walkingGps:
        return '🚶 ${DistanceCalculator.formatDistance(quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000)}';
      case QuestVerificationType.gameplayTime:
        return '🎮 Mini-Game';
      case QuestVerificationType.photoProof:
        return quest.requiresFreshPhoto ? '📸 Live Photo' : '📸 Photo';
      case QuestVerificationType.locationGps:
        return '📍 GPS';
      case QuestVerificationType.compositeRules:
      case QuestVerificationType.customConfig:
        return '✨ Quest';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(quest);
    final catIcon = _getCategoryIcon(quest.category);
    final isNearby = quest.isWithinAllowedRadius;
    final verBadge = _getVerificationBadgeText(quest);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quest.isCompleted
              ? AppColors.primary.withValues(alpha: 0.6)
              : (isNearby ? rarityColor : AppColors.borderBright),
          width: (quest.isCompleted || isNearby) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (isNearby || quest.difficulty == QuestDifficulty.legendary)
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badges Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Category Icon Capsule
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(catIcon, size: 15, color: AppColors.primary),
                    ),
                    // Rarity Badge
                    QuestRarityBadge.fromDifficulty(quest.difficulty),
                    // Verification Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        verBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    // Source Type Badge: Dynamic 50km Location vs Global Admin
                    if (quest.sourceType == 'admin')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, size: 11, color: AppColors.secondary),
                            const SizedBox(width: 3),
                            Text(
                              'GLOBAL ADMIN',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.secondary,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (quest.sourceType == 'location_generated' || quest.sourceType == 'location')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentLocation.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentLocation.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_rounded, size: 11, color: AppColors.accentLocation),
                            const SizedBox(width: 3),
                            Text(
                              '10KM LOCAL',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.accentLocation,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Completed status or Distance
                    if (quest.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'DONE',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.primary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (quest.distanceMeters != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNearby
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: isNearby
                              ? Border.all(color: AppColors.primary, width: 1)
                              : Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNearby ? Icons.my_location_rounded : Icons.near_me_outlined,
                              size: 11,
                              color: isNearby ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isNearby
                                  ? '${DistanceCalculator.formatDistance(quest.distanceMeters!)} (NEAR)'
                                  : DistanceCalculator.formatDistance(quest.distanceMeters!),
                              style: AppTypography.caption.copyWith(
                                color: isNearby ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  quest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),

                // Location line
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        quest.locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rewards Footer Row with Wrap
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildRewardBadge(
                            icon: Icons.bolt_rounded,
                            color: AppColors.accentXp,
                            text: '+${quest.xpReward} XP',
                          ),
                          _buildRewardBadge(
                            icon: Icons.monetization_on_rounded,
                            color: AppColors.secondary,
                            text: '+${quest.coinReward} Coins',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'VIEW',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardBadge({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


