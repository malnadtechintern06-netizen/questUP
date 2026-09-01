import 'dart:math' as math;

class DistanceCalculator {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculate distance between two coordinates in meters using the Haversine formula
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Checks if current location is within geofence radius of target
  static bool isWithinRadius({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    required double radiusMeters,
  }) {
    final distance = calculateDistanceMeters(
      lat1: userLat,
      lon1: userLon,
      lat2: targetLat,
      lon2: targetLon,
    );
    return distance <= radiusMeters;
  }

  /// Formats distance human-readably (e.g. "45 m", "1.2 km")
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  static double _degToRad(double deg) {
    return deg * (math.pi / 180.0);
  }
}
