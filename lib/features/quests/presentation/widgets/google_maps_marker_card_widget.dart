import 'package:flutter/material.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
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
    if (combined.contains('library') || combined.contains('reading') || combined.contains('book')) {
      return Icons.menu_book_rounded;
    }
    if (combined.contains('restaurant') || combined.contains('food') || combined.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (combined.contains('walk') || combined.contains('hiking') || combined.contains('trail')) {
      return Icons.directions_walk_rounded;
    }
    if (combined.contains('draw') || combined.contains('art')) {
      return Icons.palette_rounded;
    }
    if (combined.contains('exercise') || combined.contains('workout') || combined.contains('fitness')) {
      return Icons.fitness_center_rounded;
    }
    if (combined.contains('game') || combined.contains('puzzle')) {
      return Icons.sports_esports_rounded;
    }
    return Icons.location_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
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

        // Top Left: Map Mode Badge
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_rounded, size: 10, color: Color(0xFFEA4335)),
                const SizedBox(width: 3),
                Text(
                  'GOOGLE MAPS PIN',
                  style: AppTypography.caption.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: content,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: content,
    );
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
