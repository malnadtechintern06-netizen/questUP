import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/utils/quest_image_resolver.dart';

class QuestImageWidget extends StatefulWidget {
  final Quest quest;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final String? customImageUrl;
  final bool showGradientOverlay;

  const QuestImageWidget({
    super.key,
    required this.quest,
    this.height,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.customImageUrl,
    this.showGradientOverlay = true,
  });

  @override
  State<QuestImageWidget> createState() => _QuestImageWidgetState();
}

class _QuestImageWidgetState extends State<QuestImageWidget> {
  int _currentPhotoIndex = 0;
  bool _failedAllPlacePhotos = false;

  @override
  void didUpdateWidget(covariant QuestImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quest.id != widget.quest.id ||
        oldWidget.quest.photoReference != widget.quest.photoReference) {
      _currentPhotoIndex = 0;
      _failedAllPlacePhotos = false;
    }
  }

  String _getEffectiveUrl() {
    if (widget.customImageUrl != null) {
      return widget.customImageUrl!;
    }

    final quest = widget.quest;

    // If we have multiple Google Places photos for this exact Place ID and not all failed:
    if (!_failedAllPlacePhotos &&
        quest.photoReferences.isNotEmpty &&
        _currentPhotoIndex < quest.photoReferences.length) {
      final ref = quest.photoReferences[_currentPhotoIndex];
      return QuestImageResolver.buildGooglePhotoUrl(ref);
    }

    return QuestImageResolver.resolveQuestImageUrl(quest);
  }

  void _handlePhotoError() {
    final quest = widget.quest;
    if (_currentPhotoIndex < quest.photoReferences.length - 1) {
      // Try next photo belonging to the SAME exact Place ID
      if (mounted) {
        setState(() {
          _currentPhotoIndex++;
        });
      }
    } else {
      // Exhausted all photos for this exact place -> use fallback
      if (mounted && !_failedAllPlacePhotos) {
        setState(() {
          _failedAllPlacePhotos = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = _getEffectiveUrl();
    final isNetwork = effectiveUrl.startsWith('http://') || effectiveUrl.startsWith('https://');

    Widget imageContent;

    if (isNetwork) {
      imageContent = Image.network(
        effectiveUrl,
        key: ValueKey('${widget.quest.placeId ?? widget.quest.id}_${widget.quest.photoReference ?? ""}_$_currentPhotoIndex'),
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return ShimmerBox(
            height: widget.height ?? double.infinity,
            width: widget.width ?? double.infinity,
            borderRadius: 0,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _handlePhotoError();
            }
          });

          final fallbackUrl = QuestImageResolver.resolveCategoryFallback(widget.quest.category);
          if (fallbackUrl != effectiveUrl) {
            return Image.network(
              fallbackUrl,
              height: widget.height,
              width: widget.width,
              fit: widget.fit,
              errorBuilder: (_, _, _) => _buildIconFallback(),
            );
          }
          return _buildIconFallback();
        },
      );
    } else {
      imageContent = Image.asset(
        effectiveUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _buildIconFallback(),
      );
    }

    final decoratedWidget = Stack(
      fit: StackFit.passthrough,
      children: [
        imageContent,
        if (widget.showGradientOverlay)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: decoratedWidget,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: decoratedWidget,
    );
  }

  Widget _buildIconFallback() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(widget.quest.category),
          size: 36,
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
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
