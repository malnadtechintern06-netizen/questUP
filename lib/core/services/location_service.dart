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
    // 1. Check if location services (GPS) are enabled on the phone/emulator
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
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

    // 3. Obtain real GPS position from device / emulator
    // Tier 1: High Accuracy (GPS Satellites / Network Fused Provider)
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );

      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('High accuracy position timed out ($e). Trying Android LocationManager...');
    }

    // Tier 2: Android LocationManager (Vital for Android Emulators & indoor devices!)
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 4),
        ),
      );

      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('Android LocationManager position failed ($e). Checking last known position...');
    }

    // Tier 3: Last Known Position
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return LocationCoordinates(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          accuracy: lastKnown.accuracy,
          timestamp: lastKnown.timestamp,
        );
      }
    } catch (e) {
      debugPrint('Last known position failed: $e');
    }

    throw const LocationException('Unable to acquire GPS signal. Please ensure location is enabled in emulator settings.');
  }

  @override
  Future<LocationCoordinates> getCurrentLocation() async {
    if (_simulatedLocation != null) {
      return _simulatedLocation!;
    }

    try {
      return await getRealDeviceLocation();
    } catch (e) {
      debugPrint('Real location fetch fallback notice: $e');
      // Try last known position if available
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LocationCoordinates(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
            timestamp: lastKnown.timestamp,
          );
        }
      } catch (_) {}

      // Fallback default coordinates if GPS hardware completely unavailable
      return LocationCoordinates(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );
    }
  }
}
