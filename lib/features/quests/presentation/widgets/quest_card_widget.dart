import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../domain/entities/quest.dart';

class QuestCardWidget extends StatelessWidget {
  final Quest quest;
  final VoidCallback onTap;

  const QuestCardWidget({
    super.key,
    required this.quest,
    required this.onTap,
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
        return Icons.theater_comedy_outlined;
      case QuestCategory.mystery:
        return Icons.psychology_alt_outlined;
      case QuestCategory.location:
      case QuestCategory.landmark:
        return Icons.account_balance_outlined;
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
    final diffColor = _getDifficultyColor(quest.difficulty);
    final catIcon = _getCategoryIcon(quest.category);
    final isNearby = quest.isWithinAllowedRadius;
    final verBadge = _getVerificationBadgeText(quest);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: quest.isCompleted
              ? AppColors.primary.withValues(alpha: 0.6)
              : isNearby
                  ? AppColors.accentLocation
                  : AppColors.border,
          width: (quest.isCompleted || isNearby) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isNearby
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isNearby ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Category + Difficulty + Verification Tag + Distance / Status Badge
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(catIcon, size: 16, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        quest.difficulty.name.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: diffColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    // Verification Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        verBadge,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
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
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'COMPLETED',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (quest.distanceMeters != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNearby
                              ? AppColors.accentLocation.withValues(alpha: 0.2)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: isNearby
                              ? Border.all(color: AppColors.accentLocation, width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNearby ? Icons.my_location_rounded : Icons.near_me_outlined,
                              size: 12,
                              color: isNearby ? AppColors.accentLocation : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isNearby
                                  ? '${DistanceCalculator.formatDistance(quest.distanceMeters!)} (IN RANGE)'
                                  : '${DistanceCalculator.formatDistance(quest.distanceMeters!)} away',
                              style: AppTypography.caption.copyWith(
                                color: isNearby ? AppColors.accentLocation : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  quest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),

                // Connected Origin -> Destination Route
                if (quest.originLocationName != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, size: 11, color: AppColors.accentLocation),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            quest.originLocationName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        const Icon(Icons.location_on_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            quest.locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Location subtitle
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          quest.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Reward badges
                Row(
                  children: [
                    _buildRewardBadge(
                      icon: Icons.star_rounded,
                      color: AppColors.accentXp,
                      text: '+${quest.xpReward} XP',
                    ),
                    const SizedBox(width: 8),
                    _buildRewardBadge(
                      icon: Icons.monetization_on_rounded,
                      color: AppColors.secondary,
                      text: '+${quest.coinReward} Coins',
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppColors.textMuted,
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
