import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/quest.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  Offset _calculateBlipOffset(Quest quest, int index, LocationCoordinates? userCoords) {
    if (userCoords != null) {
      final dLat = quest.latitude - userCoords.latitude;
      final dLon = quest.longitude - userCoords.longitude;

      // Calculate bearing angle from user to quest
      // In screen coordinates: +x is East (+dLon), -y is North (+dLat)
      final angle = math.atan2(dLon, dLat);

      // Distance fraction mapped to radar radius (0 to 95 pixels max)
      final distMeters = quest.distanceMeters ?? 400.0;
      final radiusFraction = math.min(0.90, math.max(0.28, 0.28 + (distMeters / 3000.0) * 0.62));

      final dx = 95 * radiusFraction * math.sin(angle);
      final dy = -95 * radiusFraction * math.cos(angle);
      return Offset(dx, dy);
    }

    // Fallback pseudo-polar distribution if coordinates not yet available
    final angle = (index * 72.0 + 35.0) * (math.pi / 180.0);
    final radiusFraction = 0.35 + (index % 3) * 0.22;
    final dx = 95 * radiusFraction * math.cos(angle);
    final dy = 95 * radiusFraction * math.sin(angle);
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            Color(0xFF162536),
            Color(0xFF0F1722),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Concentric radar rings
            CustomPaint(
              size: const Size(240, 240),
              painter: _RadarGridPainter(),
            ),

            // Rotating sweep beam
            AnimatedBuilder(
              animation: _sweepController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _sweepController.value * 2 * math.pi,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.0),
                          AppColors.primary.withValues(alpha: 0.35),
                        ],
                        stops: const [0.75, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Center Player Marker
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.person, size: 14, color: Colors.black),
            ),

            // Nearby Quest Blips with real tactical GPS bearing
            ...widget.quests.take(6).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final quest = entry.value;
              final offset = _calculateBlipOffset(quest, index, widget.userCoordinates);

              return Transform.translate(
                offset: offset,
                child: GestureDetector(
                  onTap: () => widget.onSelectQuest(quest),
                  child: Tooltip(
                    message: '${quest.title} (${quest.distanceMeters != null ? "${quest.distanceMeters!.round()}m" : ""})',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: quest.isCompleted
                            ? AppColors.primary
                            : AppColors.secondary,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: (quest.isCompleted
                                    ? AppColors.primary
                                    : AppColors.secondary)
                                .withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        quest.isCompleted
                            ? Icons.check
                            : Icons.near_me_rounded,
                        size: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Overlay Info Badge
            Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
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
                      'GPS SCANNING ACTIVE',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Rings
    canvas.drawCircle(center, 40, paint);
    canvas.drawCircle(center, 75, paint);
    canvas.drawCircle(center, 110, paint);

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - 110, center.dy),
      Offset(center.dx + 110, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 110),
      Offset(center.dx, center.dy + 110),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
