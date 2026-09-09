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
          distanceFilter: 15, // Fire stream when moving >= 15 meters (smooth tracking without micro-jitter floods)
        ),
      ).map((pos) => LocationCoordinates(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          ));
    } catch (e) {
      debugPrint('[LOCATION] Position stream notice: $e');
      return _simulatedStreamController.stream;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      debugPrint('[LOCATION] Checking GPS service');
      final enabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[LOCATION] GPS service enabled: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('[LOCATION] Error checking location service: $e');
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
      debugPrint('[LOCATION] Error checking location permission: $e');
      return false;
    }
  }

  @override
  Future<bool> isLocationEnabledAndPermitted() async {
    if (isSimulated) return true;
    try {
      final hasPerm = await hasLocationPermission();
      if (!hasPerm) return false;
      final isServiceOn = await isLocationServiceEnabled();
      return isServiceOn;
    } catch (e) {
      debugPrint('[LOCATION] Error checking isLocationEnabledAndPermitted: $e');
      return false;
    }
  }

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      debugPrint('[LOCATION] Checking permission');
      final permission = await Geolocator.checkPermission();
      debugPrint('[LOCATION] Permission result: $permission');
      return permission;
    } catch (e) {
      debugPrint('[LOCATION] Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    try {
      debugPrint('[LOCATION] Requesting permission');
      final permission = await Geolocator.requestPermission();
      debugPrint('[LOCATION] Permission after request: $permission');
      return permission;
    } catch (e) {
      debugPrint('[LOCATION] Error requesting location permission: $e');
      return LocationPermission.denied;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      debugPrint('[LOCATION] Opening Android App Settings for QuestUP');
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('[LOCATION] Error opening app settings: $e');
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      debugPrint('[LOCATION] Opening Android Device Location Settings');
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('[LOCATION] Error opening location settings: $e');
      return false;
    }
  }

  @override
  Future<LocationCoordinates> getRealDeviceLocation() async {
    final sw = Stopwatch()..start();
    debugPrint('[LOCATION] Requesting current position');

    // 1. Fast Tier 1: Instant Last Known Position (5ms)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint('[LOCATION] Position received: ${lastKnown.latitude}, ${lastKnown.longitude} (Last known, ${sw.elapsedMilliseconds}ms)');
        
        // Trigger non-blocking background fine-grain GPS refresh
        unawaited(
          Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          ).then((pos) {
            debugPrint('[LOCATION] Background fine GPS position received: ${pos.latitude}, ${pos.longitude}');
          }).catchError((_) {}),
        );

        debugPrint('[LOCATION] Location flow completed');
        return LocationCoordinates(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          accuracy: lastKnown.accuracy,
          timestamp: lastKnown.timestamp,
        );
      }
    } catch (_) {}

    // 2. Fast Tier 2: Real-time GPS Position with 2.5s timeLimit
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 2, milliseconds: 500),
        ),
      );

      debugPrint('[LOCATION] Position received: ${position.latitude}, ${position.longitude} (GPS lock, ${sw.elapsedMilliseconds}ms)');
      debugPrint('[LOCATION] Location flow completed');
      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('[LOCATION] GPS query fallback: $e');
    }

    // 3. Tier 3: Android LocationManager fallback with 1.5s timeout
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.low,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 1, milliseconds: 500),
        ),
      );

      debugPrint('[LOCATION] Position received: ${position.latitude}, ${position.longitude} (LocationManager, ${sw.elapsedMilliseconds}ms)');
      debugPrint('[LOCATION] Location flow completed');
      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (_) {}

    throw const LocationException('Unable to get your current location. Please ensure location is enabled and try again.');
  }

  @override
  Future<LocationCoordinates> getCurrentLocation() async {
    if (_simulatedLocation != null) {
      debugPrint('[LOCATION] Position received: ${_simulatedLocation!.latitude}, ${_simulatedLocation!.longitude} (Simulated)');
      debugPrint('[LOCATION] Location flow completed');
      return _simulatedLocation!;
    }

    return await getRealDeviceLocation();
  }
}
