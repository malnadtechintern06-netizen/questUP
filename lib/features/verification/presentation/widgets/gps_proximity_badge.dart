import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/distance_calculator.dart';

class GpsProximityBadge extends StatelessWidget {
  final double userLat;
  final double userLon;
  final double targetLat;
  final double targetLon;
  final double radiusMeters;

  const GpsProximityBadge({
    super.key,
    required this.userLat,
    required this.userLon,
    required this.targetLat,
    required this.targetLon,
    required this.radiusMeters,
  });

  @override
  Widget build(BuildContext context) {
    final distance = DistanceCalculator.calculateDistanceMeters(
      lat1: userLat,
      lon1: userLon,
      lat2: targetLat,
      lon2: targetLon,
    );
    final isWithinRadius = distance <= radiusMeters;
    final color = isWithinRadius ? AppColors.accentSuccess : AppColors.accentDanger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWithinRadius ? Icons.verified_user_rounded : Icons.location_off_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWithinRadius ? 'GPS GEOFENCE REACHED' : 'TOO FAR FROM TARGET',
                  style: AppTypography.badge.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  isWithinRadius
                      ? 'You are within ${DistanceCalculator.formatDistance(distance)} of the waypoint!'
                      : 'You are ${DistanceCalculator.formatDistance(distance)} away. Move closer (within ${radiusMeters.round()}m).',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
