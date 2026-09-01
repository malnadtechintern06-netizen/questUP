import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/quest.dart';

class CategoryFilterChips extends StatelessWidget {
  final QuestCategory? selectedCategory;
  final Function(QuestCategory?) onSelected;

  const CategoryFilterChips({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  String _getCategoryLabel(QuestCategory cat) {
    switch (cat) {
      case QuestCategory.location:
      case QuestCategory.landmark:
        return '📍 Nearby / Landmarks';
      case QuestCategory.reading:
        return '📖 Reading';
      case QuestCategory.writing:
        return '✍️ Writing';
      case QuestCategory.drawing:
        return '🎨 Drawing';
      case QuestCategory.exercise:
      case QuestCategory.fitness:
        return '🏃 Exercise';
      case QuestCategory.gaming:
        return '🎮 Gaming';
      case QuestCategory.food:
        return '🍎 Food';
      case QuestCategory.walking:
        return '🚶 Walking';
      case QuestCategory.nature:
        return '🌳 Nature';
      case QuestCategory.photo:
        return '📸 Photo';
      case QuestCategory.observation:
        return '🔎 Observation';
      case QuestCategory.study:
        return '📚 Study';
      case QuestCategory.video:
        return '🎥 Video';
      case QuestCategory.timed:
        return '⏱️ Timed';
      case QuestCategory.custom:
        return '🎯 Custom';
      case QuestCategory.culture:
        return '🎭 Culture';
      case QuestCategory.mystery:
        return '🔮 Mystery';
    }
  }

  static const List<QuestCategory> primaryCategories = [
    QuestCategory.landmark,
    QuestCategory.reading,
    QuestCategory.writing,
    QuestCategory.drawing,
    QuestCategory.exercise,
    QuestCategory.gaming,
    QuestCategory.food,
    QuestCategory.walking,
    QuestCategory.nature,
    QuestCategory.photo,
    QuestCategory.study,
    QuestCategory.observation,
    QuestCategory.custom,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip(
            label: '✨ All Categories',
            isSelected: selectedCategory == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...primaryCategories.map((cat) {
            final isSelected = selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildChip(
                label: _getCategoryLabel(cat),
                isSelected: isSelected,
                onTap: () => onSelected(isSelected ? null : cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
