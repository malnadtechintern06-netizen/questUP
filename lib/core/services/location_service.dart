import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quest_up/core/errors/exceptions.dart';

class LocationCoordinates {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() => 'Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)}';
}

abstract class ILocationService {
  Future<LocationCoordinates> getCurrentLocation();
  Future<LocationCoordinates> getRealDeviceLocation();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<bool> hasLocationPermission();
  Future<bool> isLocationEnabledAndPermitted();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Stream<LocationCoordinates> get locationStream;
  void setSimulatedLocation(double latitude, double longitude);
  void clearSimulatedLocation();
  bool get isSimulated;
}

class LocationService implements ILocationService {
  LocationCoordinates? _simulatedLocation;
  final StreamController<LocationCoordinates> _simulatedStreamController =
      StreamController<LocationCoordinates>.broadcast();

  @override
  bool get isSimulated => _simulatedLocation != null;

  @override
  void setSimulatedLocation(double latitude, double longitude) {
    final coords = LocationCoordinates(
      latitude: latitude,
      longitude: longitude,
      accuracy: 5.0,
      timestamp: DateTime.now(),
    );
    _simulatedLocation = coords;
    _simulatedStreamController.add(coords);
  }

  @override
  void clearSimulatedLocation() {
    _simulatedLocation = null;
  }

  @override
  Stream<LocationCoordinates> get locationStream {
    if (_simulatedLocation != null) {
      return _simulatedStreamController.stream;
    }

    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Fire stream when moving >= 5 meters
        ),
      ).map((pos) => LocationCoordinates(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          ));
    } catch (e) {
      debugPrint('Position stream notice: $e');
      return _simulatedStreamController.stream;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  @override
  Future<bool> hasLocationPermission() async {
    try {
      final permission = await checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  @override
  Future<bool> isLocationEnabledAndPermitted() async {
    if (isSimulated) return true;
    try {
      final isServiceOn = await isLocationServiceEnabled();
      if (!isServiceOn) return false;
      return await hasLocationPermission();
    } catch (e) {
      debugPrint('Error checking isLocationEnabledAndPermitted: $e');
      return false;
    }
  }

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return LocationPermission.denied;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
    }
  }

  @override
  Future<LocationCoordinates> getRealDeviceLocation() async {
    final sw = Stopwatch()..start();
    debugPrint('[QUESTUP] Requesting GPS location...');

    // 1. Check if location services (GPS) are enabled on the phone/emulator
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint('[QUESTUP] Using last known location: ${lastKnown.latitude}, ${lastKnown.longitude}');
        return LocationCoordinates(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          accuracy: lastKnown.accuracy,
          timestamp: lastKnown.timestamp,
        );
      }
      throw const LocationException(
        'GPS / Location Services are turned off on your device. Please enable GPS in device settings.',
      );
    }

    // 2. Check permission status & request if denied
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission was denied. QuestUP needs your location to detect nearby quests.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Please enable location permissions in Android Settings > Apps > QuestUP.',
      );
    }

    // 3. Fast Tier 1: Instant Last Known Position (5ms)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint('[QUESTUP] Instant last known location acquired in ${sw.elapsedMilliseconds}ms: ${lastKnown.latitude.toStringAsFixed(4)}, ${lastKnown.longitude.toStringAsFixed(4)}');
        
        // Trigger non-blocking background fine-grain GPS refresh
        unawaited(
          Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          ).then((pos) {
            debugPrint('[QUESTUP] Background fine GPS updated: ${pos.latitude}, ${pos.longitude}');
          }).catchError((_) {}),
        );

        return LocationCoordinates(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          accuracy: lastKnown.accuracy,
          timestamp: lastKnown.timestamp,
        );
      }
    } catch (_) {}

    // 4. Fast Tier 2: Real-time GPS Position with 2.5s timeLimit
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 2, milliseconds: 500),
        ),
      );

      debugPrint('[QUESTUP] GPS received in ${sw.elapsedMilliseconds}ms: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('[QUESTUP] GPS query fallback: $e');
    }

    // 5. Tier 3: Android LocationManager fallback with 1.5s timeout
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.low,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 1, milliseconds: 500),
        ),
      );

      debugPrint('[QUESTUP] Android LocationManager position in ${sw.elapsedMilliseconds}ms: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (_) {}

    throw const LocationException('Unable to acquire GPS signal. Please ensure location is enabled.');
  }

  @override
  Future<LocationCoordinates> getCurrentLocation() async {
    if (_simulatedLocation != null) {
      return _simulatedLocation!;
    }

    return await getRealDeviceLocation();
  }
}
