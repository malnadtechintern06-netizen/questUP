import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/quests/domain/entities/quest.dart';

enum QuestRarityTier {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class QuestRarityBadge extends StatelessWidget {
  final QuestRarityTier rarity;
  final bool showGlow;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const QuestRarityBadge({
    super.key,
    required this.rarity,
    this.showGlow = true,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  factory QuestRarityBadge.fromDifficulty(QuestDifficulty difficulty) {
    switch (difficulty) {
      case QuestDifficulty.easy:
        return const QuestRarityBadge(rarity: QuestRarityTier.uncommon);
      case QuestDifficulty.medium:
        return const QuestRarityBadge(rarity: QuestRarityTier.rare);
      case QuestDifficulty.hard:
        return const QuestRarityBadge(rarity: QuestRarityTier.epic);
      case QuestDifficulty.legendary:
        return const QuestRarityBadge(rarity: QuestRarityTier.legendary);
    }
  }

  factory QuestRarityBadge.fromString(String text) {
    switch (text.toLowerCase()) {
      case 'common':
        return const QuestRarityBadge(rarity: QuestRarityTier.common);
      case 'uncommon':
      case 'easy':
        return const QuestRarityBadge(rarity: QuestRarityTier.uncommon);
      case 'rare':
      case 'medium':
        return const QuestRarityBadge(rarity: QuestRarityTier.rare);
      case 'epic':
      case 'hard':
        return const QuestRarityBadge(rarity: QuestRarityTier.epic);
      case 'legendary':
      case 'mythic':
        return const QuestRarityBadge(rarity: QuestRarityTier.legendary);
      default:
        return const QuestRarityBadge(rarity: QuestRarityTier.common);
    }
  }

  Color get _color {
    switch (rarity) {
      case QuestRarityTier.common:
        return AppColors.rarityCommon;
      case QuestRarityTier.uncommon:
        return AppColors.rarityUncommon;
      case QuestRarityTier.rare:
        return AppColors.rarityRare;
      case QuestRarityTier.epic:
        return AppColors.rarityEpic;
      case QuestRarityTier.legendary:
        return AppColors.rarityLegendary;
    }
  }

  String get _name {
    switch (rarity) {
      case QuestRarityTier.common:
        return 'COMMON';
      case QuestRarityTier.uncommon:
        return 'UNCOMMON';
      case QuestRarityTier.rare:
        return 'RARE';
      case QuestRarityTier.epic:
        return 'EPIC';
      case QuestRarityTier.legendary:
        return 'LEGENDARY';
    }
  }

  IconData get _icon {
    switch (rarity) {
      case QuestRarityTier.common:
        return Icons.circle_outlined;
      case QuestRarityTier.uncommon:
        return Icons.shield_outlined;
      case QuestRarityTier.rare:
        return Icons.flash_on_rounded;
      case QuestRarityTier.epic:
        return Icons.auto_awesome_rounded;
      case QuestRarityTier.legendary:
        return Icons.workspace_premium_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.0),
        boxShadow: showGlow && rarity != QuestRarityTier.common
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: rarity == QuestRarityTier.legendary ? 10 : 6,
                  spreadRadius: rarity == QuestRarityTier.legendary ? 1 : 0,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: fontSize + 2, color: color),
          const SizedBox(width: 4),
          Text(
            _name,
            style: AppTypography.badge.copyWith(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
