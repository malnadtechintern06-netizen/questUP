import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final mapsLauncherServiceProvider = Provider<MapsLauncherService>((ref) {
  return MapsLauncherService();
});

class MapsLauncherService {
  /// Opens Google Maps centered at the specified coordinates with an optional label marker.
  Future<bool> openGoogleMapsLocation(double lat, double lon, {String? label}) async {
    final query = label != null ? Uri.encodeComponent(label) : '$lat,$lon';
    
    // 1. Try native Google Maps intent on Android
    if (!kIsWeb && Platform.isAndroid) {
      final nativeUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon($query)');
      if (await canLaunchUrl(nativeUri)) {
        try {
          return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }

    // 2. Fallback to standard Google Maps universal web URL
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(webUri)) {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Opens Google Maps with direct turn-by-turn route directions from the user's live coordinates to the target destination.
  Future<bool> openGoogleMapsDirections({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String? destinationName,
  }) async {
    // 1. Try native Google navigation intent on Android
    if (!kIsWeb && Platform.isAndroid) {
      final nativeNavUri = Uri.parse('google.navigation:q=$destLat,$destLon&mode=w');
      if (await canLaunchUrl(nativeNavUri)) {
        try {
          return await launchUrl(nativeNavUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }

    // 2. Standard Google Maps Directions URL (Supports walking mode 'w')
    final encodedDestName = destinationName != null ? Uri.encodeComponent(destinationName) : '$destLat,$destLon';
    final directionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLon&destination=$destLat,$destLon&travelmode=walking',
    );

    if (await canLaunchUrl(directionsUri)) {
      return await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
    }

    // 3. Fallback search query
    final fallbackUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedDestName');
    if (await canLaunchUrl(fallbackUri)) {
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }

    return false;
  }
}
