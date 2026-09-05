import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../../../core/widgets/quest_rarity_badge.dart';
import '../../domain/entities/quest.dart';
import 'google_maps_marker_card_widget.dart';

class RadarDisplayWidget extends StatefulWidget {
  final List<Quest> quests;
  final LocationCoordinates? userCoordinates;
  final Function(Quest quest) onSelectQuest;

  const RadarDisplayWidget({
    super.key,
    required this.quests,
    this.userCoordinates,
    required this.onSelectQuest,
  });

  @override
  State<RadarDisplayWidget> createState() => _RadarDisplayWidgetState();
}

class _RadarDisplayWidgetState extends State<RadarDisplayWidget>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Quest? _selectedPreviewQuest;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Offset _calculateBlipOffset(Quest quest, int index, LocationCoordinates? userCoords) {
    if (userCoords != null) {
      final dLat = quest.latitude - userCoords.latitude;
      final dLon = quest.longitude - userCoords.longitude;

      final angle = math.atan2(dLon, dLat);
      final distMeters = quest.distanceMeters ?? 400.0;
      final radiusFraction = math.min(0.88, math.max(0.28, 0.28 + (distMeters / 3000.0) * 0.60));

      final dx = 100 * radiusFraction * math.sin(angle);
      final dy = -100 * radiusFraction * math.cos(angle);
      return Offset(dx, dy);
    }

    final angle = (index * 72.0 + 35.0) * (math.pi / 180.0);
    final radiusFraction = 0.35 + (index % 3) * 0.22;
    final dx = 100 * radiusFraction * math.cos(angle);
    final dy = 100 * radiusFraction * math.sin(angle);
    return Offset(dx, dy);
  }

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

  void _showQuestPreview(Quest quest) {
    setState(() {
      _selectedPreviewQuest = quest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 250,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderBright, width: 1.2),
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                Color(0xFF132035),
                Color(0xFF090D15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Concentric tactical grid & crosshairs
                CustomPaint(
                  size: const Size(250, 250),
                  painter: _RadarGridPainter(),
                ),

                // Rotating sweeping beam with gradient trail
                AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _sweepController.value * 2 * math.pi,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary.withValues(alpha: 0.0),
                              AppColors.primary.withValues(alpha: 0.35),
                            ],
                            stops: const [0.0, 0.70, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Center Pulsing GPS Marker (Player)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return Container(
                      width: 28 * _pulseAnimation.value,
                      height: 28 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(
                          alpha: (1.0 - (_pulseAnimation.value - 1.0) / 0.6).clamp(0.0, 0.4),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.navigation_rounded, size: 12, color: Colors.black),
                  ),
                ),

                // Nearby Quest Blips
                ...widget.quests.take(6).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final quest = entry.value;
                  final offset = _calculateBlipOffset(quest, index, widget.userCoordinates);
                  final rarityColor = _getRarityColor(quest);
                  final isSelected = _selectedPreviewQuest?.id == quest.id;

                  return Transform.translate(
                    offset: offset,
                    child: GestureDetector(
                      onTap: () => _showQuestPreview(quest),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(isSelected ? 6 : 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: rarityColor,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: rarityColor.withValues(alpha: isSelected ? 0.9 : 0.6),
                              blurRadius: isSelected ? 16 : 10,
                              spreadRadius: isSelected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          quest.isCompleted ? Icons.check_rounded : Icons.place_rounded,
                          size: isSelected ? 16 : 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                }),

                // Status Overlay Badge
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TACTICAL RADAR ACTIVE',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${widget.quests.length} IN RANGE',
                      style: AppTypography.badge.copyWith(
                        color: AppColors.secondary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating 3D Quest Preview Card when marker tapped
        if (_selectedPreviewQuest != null) ...[
          const SizedBox(height: 12),
          _buildFloatingPreviewCard(context, _selectedPreviewQuest!),
        ],
      ],
    );
  }

  Widget _buildFloatingPreviewCard(BuildContext context, Quest quest) {
    final distStr = DistanceCalculator.formatDistance(quest.distanceMeters ?? 0);
    final rarityColor = _getRarityColor(quest);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rarityColor.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => widget.onSelectQuest(quest),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Mini Photo Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: GoogleMapsMarkerCardWidget(
                      quest: quest,
                      height: 70,
                      width: 70,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          QuestRarityBadge.fromDifficulty(quest.difficulty),
                          const Spacer(),
                          Text(
                            distStr,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        quest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFEA4335)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              quest.locationName,
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '+${quest.xpReward} XP',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accentXp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${quest.coinReward} Coins',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OPEN →',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.primary,
                                fontSize: 9.5,
                              ),
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
        ),
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gridPaint = Paint()
      ..color = AppColors.borderBright.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final ringPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Tactical Rings
    canvas.drawCircle(center, 38, ringPaint);
    canvas.drawCircle(center, 74, ringPaint);
    canvas.drawCircle(center, 110, ringPaint);

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - 110, center.dy),
      Offset(center.dx + 110, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 110),
      Offset(center.dx, center.dy + 110),
      gridPaint,
    );

    // Diagonal tick marks
    final tickPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawLine(
      Offset(center.dx - 70, center.dy - 70),
      Offset(center.dx + 70, center.dy + 70),
      tickPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 70, center.dy + 70),
      Offset(center.dx + 70, center.dy - 70),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

