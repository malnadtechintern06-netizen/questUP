import 'package:flutter/material.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';

class GoogleMapsMarkerCardWidget extends StatefulWidget {
  final Quest quest;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final VoidCallback? onMapTap;

  const GoogleMapsMarkerCardWidget({
    super.key,
    required this.quest,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius,
    this.onMapTap,
  });

  @override
  State<GoogleMapsMarkerCardWidget> createState() => _GoogleMapsMarkerCardWidgetState();
}

class _GoogleMapsMarkerCardWidgetState extends State<GoogleMapsMarkerCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isLocationQuest {
    return widget.quest.category == QuestCategory.landmark ||
        widget.quest.category == QuestCategory.location;
  }

  String _getMapUrl() {
    final lat = widget.quest.latitude;
    final lon = widget.quest.longitude;

    if (lat == 0.0 && lon == 0.0) {
      return '';
    }

    if (AppConstants.googleMapsApiKey.isNotEmpty) {
      return 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lon&zoom=16&size=600x300&scale=2&maptype=roadmap&markers=color:red%7C$lat,$lon&key=${AppConstants.googleMapsApiKey}';
    }

    // OpenStreetMap Static Map Tile
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=$lat,$lon&zoom=16&size=600x300';
  }

  IconData _getMarkerIcon(Quest quest) {
    final combined = '${quest.locationName} ${quest.placeCategory ?? ''} ${quest.title}'.toLowerCase();
    if (combined.contains('bus') || combined.contains('station') || combined.contains('transit')) {
      return Icons.directions_bus_rounded;
    }
    if (combined.contains('hospital') || combined.contains('clinic') || combined.contains('health')) {
      return Icons.local_hospital_rounded;
    }
    if (combined.contains('college') || combined.contains('university') || combined.contains('school') || combined.contains('campus')) {
      return Icons.school_rounded;
    }
    if (combined.contains('temple') || combined.contains('mandir') || combined.contains('shrine') || combined.contains('worship') || combined.contains('devasthana')) {
      return Icons.temple_hindu_rounded;
    }
    if (combined.contains('church') || combined.contains('cathedral')) {
      return Icons.church_rounded;
    }
    if (combined.contains('mosque') || combined.contains('masjid')) {
      return Icons.mosque_rounded;
    }
    if (combined.contains('waterfall') || combined.contains('falls') || combined.contains('lake') || combined.contains('river')) {
      return Icons.water_rounded;
    }
    if (combined.contains('park') || combined.contains('garden') || combined.contains('forest') || combined.contains('tree')) {
      return Icons.park_rounded;
    }
    if (combined.contains('market') || combined.contains('mall') || combined.contains('shop')) {
      return Icons.shopping_bag_rounded;
    }
    return Icons.location_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // If this is a landmark or location quest, render Google Maps / location imagery
    if (_isLocationQuest) {
      return _buildLocationMapCard();
    }

    // For all other categories (writing, drawing, fitness, reading, gaming, etc.), render rich Activity Thematic Banner
    return _buildThematicActivityBanner();
  }

  Widget _buildLocationMapCard() {
    final mapUrl = _getMapUrl();
    final hasCoordinates = widget.quest.latitude != 0.0 && widget.quest.longitude != 0.0;
    final markerIcon = _getMarkerIcon(widget.quest);

    Widget background;

    if (mapUrl.isNotEmpty) {
      background = Image.network(
        mapUrl,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return ShimmerBox(
            height: widget.height ?? double.infinity,
            width: widget.width ?? double.infinity,
            borderRadius: 0,
          );
        },
        errorBuilder: (_, _, _) => _buildVectorMapBackground(),
      );
    } else {
      background = _buildVectorMapBackground();
    }

    final content = Stack(
      children: [
        // Map Imagery / Canvas
        Positioned.fill(child: background),

        // Semi-transparent Map Overlay Gradients
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),

        // Center Google Maps Pin Marker
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Google Maps Pinpoint Marker Pin
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.08);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335), // Google Maps Red
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA4335).withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      markerIcon,
                      size: 16,
                      color: const Color(0xFFEA4335),
                    ),
                  ),
                ),
              ),

              // Pin Stem & Pulsing Waypoint Ground Disc
              CustomPaint(
                size: const Size(10, 6),
                painter: _PinStemPainter(color: const Color(0xFFEA4335)),
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final radius = 6.0 + (_pulseController.value * 8.0);
                  final opacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);
                  return Container(
                    width: radius * 2,
                    height: (radius * 2) * 0.4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA4335).withValues(alpha: opacity * 0.5),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Bottom Left: GPS Coordinates Chip
        if (hasCoordinates)

          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 9, color: AppColors.accentLocation),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.quest.latitude.toStringAsFixed(4)}°, ${widget.quest.longitude.toStringAsFixed(4)}°',
                    style: AppTypography.caption.copyWith(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return _wrapBorderRadius(content);
  }

  Widget _buildThematicActivityBanner() {
    final cat = widget.quest.category;
    final theme = _getActivityTheme(cat);

    final content = Stack(
      children: [
        // 1. Dynamic Mesh Gradient Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.gradientColors,
              ),
            ),
          ),
        ),

        // 2. Artistic Motif Background Pattern
        Positioned.fill(
          child: CustomPaint(
            painter: _ActivityMotifPainter(
              category: cat,
              accentColor: theme.accentColor,
            ),
          ),
        ),

        // 3. Ambient Glow Gradients
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: [
                  theme.accentColor.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),

        // 4. Center Glowing Activity Emblem
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.06);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.accentColor.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      theme.icon,
                      size: 22,
                      color: theme.accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 5. Top Left Activity Mode Badge
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.accentColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(theme.icon, size: 10, color: theme.accentColor),
                const SizedBox(width: 4),
                Text(
                  theme.badgeLabel.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 6. Bottom Left Objective Challenge Pill
        Positioned(
          bottom: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 10, color: AppColors.secondary),
                const SizedBox(width: 3),
                Text(
                  _getChallengeObjectiveText(widget.quest),
                  style: AppTypography.caption.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return _wrapBorderRadius(content);
  }

  Widget _wrapBorderRadius(Widget child) {
    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: child,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: child,
    );
  }

  String _getChallengeObjectiveText(Quest quest) {
    if (quest.hasObjectDetection) {
      final obj = quest.requiredObject ?? 'Object';
      return 'Detect: ${obj[0].toUpperCase()}${obj.substring(1)}';
    }

    switch (quest.verificationType) {
      case QuestVerificationType.drawingCanvas:
        return 'Canvas: ${quest.requiredDrawingSubject ?? 'Sketch'}';
      case QuestVerificationType.writingText:
        return quest.requiredWords > 0 ? '${quest.requiredWords} Words Target' : 'Creative Writing';
      case QuestVerificationType.timedActivity:
      case QuestVerificationType.timedVideo:
      case QuestVerificationType.videoProof:
        final mins = (quest.requiredDurationSeconds ~/ 60);
        return '${mins > 0 ? '$mins min' : 'Timed'} Challenge';
      case QuestVerificationType.walkingGps:
        return '${DistanceCalculator.formatDistance(quest.requiredDistanceMeters > 0 ? quest.requiredDistanceMeters : 1000)} Walk';
      case QuestVerificationType.gameplayTime:
        return 'Interactive Mini-Game';
      case QuestVerificationType.photoProof:
        return quest.requiresFreshPhoto ? 'Live Photo Capture' : 'Photo Proof';
      default:
        return 'Active Quest';
    }
  }

  _ActivityTheme _getActivityTheme(QuestCategory category) {
    switch (category) {
      case QuestCategory.writing:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF451A03), // Deep Amber Brown
            const Color(0xFFB45309), // Rich Amber
            const Color(0xFFD97706), // Warm Gold
          ],
          accentColor: const Color(0xFFFBBF24),
          icon: Icons.edit_note_rounded,
          badgeLabel: 'Writing Workshop',
        );

      case QuestCategory.drawing:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF064E3B), // Deep Emerald
            const Color(0xFF047857), // Forest Teal
            const Color(0xFF10B981), // Vivid Mint
          ],
          accentColor: const Color(0xFF34D399),
          icon: Icons.palette_rounded,
          badgeLabel: 'Creative Canvas',
        );

      case QuestCategory.reading:
      case QuestCategory.study:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF1E1B4B), // Midnight Indigo
            const Color(0xFF3730A3), // Royal Indigo
            const Color(0xFF6366F1), // Electric Violet
          ],
          accentColor: const Color(0xFF818CF8),
          icon: Icons.menu_book_rounded,
          badgeLabel: 'Study & Reading',
        );

      case QuestCategory.exercise:
      case QuestCategory.fitness:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF7C2D12), // Deep Flame
            const Color(0xFFC2410C), // Blaze Orange
            const Color(0xFFEA580C), // Sunset Coral
          ],
          accentColor: const Color(0xFFFB923C),
          icon: Icons.fitness_center_rounded,
          badgeLabel: 'Fitness Workout',
        );

      case QuestCategory.gaming:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF3B0764), // Cyber Purple
            const Color(0xFF6B21A8), // Deep Violet
            const Color(0xFFA855F7), // Neon Purple
          ],
          accentColor: const Color(0xFFC084FC),
          icon: Icons.sports_esports_rounded,
          badgeLabel: 'Mini-Game Arena',
        );

      case QuestCategory.food:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF78350F), // Spiced Cinnamon
            const Color(0xFFD97706), // Warm Honey
            const Color(0xFFF59E0B), // Saffron
          ],
          accentColor: const Color(0xFFFDE047),
          icon: Icons.restaurant_rounded,
          badgeLabel: 'Culinary Quest',
        );

      case QuestCategory.walking:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF14532D), // Deep Forest
            const Color(0xFF15803D), // Leaf Green
            const Color(0xFF22C55E), // Neon Emerald
          ],
          accentColor: const Color(0xFF4ADE80),
          icon: Icons.directions_walk_rounded,
          badgeLabel: 'Walking Explorer',
        );

      case QuestCategory.nature:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF064E3B), // Deep Pine
            const Color(0xFF059669), // Mountain Emerald
            const Color(0xFF34D399), // Spring Green
          ],
          accentColor: const Color(0xFF6EE7B7),
          icon: Icons.forest_rounded,
          badgeLabel: 'Nature Trail',
        );

      case QuestCategory.observation:
      case QuestCategory.photo:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF083344), // Deep Cyan
            const Color(0xFF0369A1), // Ocean Cerulean
            const Color(0xFF06B6D4), // Electric Cyan
          ],
          accentColor: const Color(0xFF38BDF8),
          icon: Icons.photo_camera_rounded,
          badgeLabel: 'Photo Mission',
        );

      case QuestCategory.video:
      case QuestCategory.timed:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF4C0519), // Deep Wine
            const Color(0xFF9F1239), // Rose Crimson
            const Color(0xFFE11D48), // Ruby Flame
          ],
          accentColor: const Color(0xFFFB7185),
          icon: Icons.timer_rounded,
          badgeLabel: 'Timed Focus',
        );

      case QuestCategory.culture:
      case QuestCategory.mystery:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF2E1065), // Mystic Night
            const Color(0xFF581C87), // Royal Purple
            const Color(0xFF7E22CE), // Arcane Violet
          ],
          accentColor: const Color(0xFFE9D5FF),
          icon: Icons.psychology_alt_rounded,
          badgeLabel: 'Mystery & Puzzle',
        );

      default:
        return _ActivityTheme(
          gradientColors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
          accentColor: AppColors.primary,
          icon: Icons.military_tech_rounded,
          badgeLabel: 'Special Quest',
        );
    }
  }

  Widget _buildVectorMapBackground() {
    return Container(
      color: const Color(0xFF1E293B),
      child: CustomPaint(
        painter: _VectorMapPainter(),
      ),
    );
  }
}

class _ActivityTheme {
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String badgeLabel;

  const _ActivityTheme({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.badgeLabel,
  });
}

class _ActivityMotifPainter extends CustomPainter {
  final QuestCategory category;
  final Color accentColor;

  _ActivityMotifPainter({
    required this.category,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final subtlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Background geometric rings & aura
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 48, glowPaint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.8), 36, glowPaint);

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.height * 0.6, subtlePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.height * 0.9, subtlePaint);

    // Category specific decorative motifs
    switch (category) {
      case QuestCategory.writing:
        // Lined notebook waves
        for (double y = size.height * 0.25; y <= size.height * 0.75; y += 12) {
          canvas.drawLine(Offset(size.width * 0.1, y), Offset(size.width * 0.9, y), subtlePaint);
        }
        break;

      case QuestCategory.drawing:
        // Creative artistic arcs
        final arcPath = Path()
          ..moveTo(0, size.height * 0.7)
          ..quadraticBezierTo(size.width * 0.4, size.height * 0.2, size.width, size.height * 0.6);
        canvas.drawPath(arcPath, subtlePaint..strokeWidth = 2.5);
        break;

      case QuestCategory.fitness:
      case QuestCategory.exercise:
        // ECG Heart Pulse wave
        final pulsePath = Path()
          ..moveTo(0, size.height * 0.5)
          ..lineTo(size.width * 0.35, size.height * 0.5)
          ..lineTo(size.width * 0.42, size.height * 0.25)
          ..lineTo(size.width * 0.5, size.height * 0.75)
          ..lineTo(size.width * 0.58, size.height * 0.4)
          ..lineTo(size.width * 0.65, size.height * 0.5)
          ..lineTo(size.width, size.height * 0.5);
        canvas.drawPath(pulsePath, subtlePaint..strokeWidth = 2.0);
        break;

      case QuestCategory.gaming:
        // Digital cyber grid lines
        for (double x = size.width * 0.2; x <= size.width * 0.8; x += 24) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), subtlePaint);
        }
        break;

      case QuestCategory.photo:
      case QuestCategory.observation:
        // Camera viewfinder corner brackets
        final bracketPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        final margin = 16.0;
        final length = 12.0;
        // Top-left corner
        canvas.drawLine(Offset(margin, margin + length), Offset(margin, margin), bracketPaint);
        canvas.drawLine(Offset(margin, margin), Offset(margin + length, margin), bracketPaint);
        // Top-right corner
        canvas.drawLine(Offset(size.width - margin - length, margin), Offset(size.width - margin, margin), bracketPaint);
        canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + length), bracketPaint);
        // Bottom-left corner
        canvas.drawLine(Offset(margin, size.height - margin - length), Offset(margin, size.height - margin), bracketPaint);
        canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + length, size.height - margin), bracketPaint);
        // Bottom-right corner
        canvas.drawLine(Offset(size.width - margin - length, size.height - margin), Offset(size.width - margin, size.height - margin), bracketPaint);
        canvas.drawLine(Offset(size.width - margin, size.height - margin - length), Offset(size.width - margin, size.height - margin), bracketPaint);
        break;

      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityMotifPainter oldDelegate) => false;
}

class _PinStemPainter extends CustomPainter {
  final Color color;

  _PinStemPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinStemPainter oldDelegate) => oldDelegate.color != color;
}

class _VectorMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final highwayPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.15)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final waterPaint = Paint()
      ..color = const Color(0xFF1E88E5).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Water contour
    final waterPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width, size.height * 0.85)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    // Minor roads grid
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.6), Offset(size.width, size.height * 0.55), roadPaint);
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.2, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.8, size.height), roadPaint);

    // Main highway
    final highwayPath = Path()
      ..moveTo(0, size.height * 0.45)
      ..cubicTo(
        size.width * 0.35, size.height * 0.4,
        size.width * 0.65, size.height * 0.5,
        size.width, size.height * 0.4,
      );
    canvas.drawPath(highwayPath, highwayPaint);
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) => false;
}
