import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/services/location_service.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';

enum LocationPermissionUIState {
  initial,
  checking,
  permissionDenied,
  permissionDeniedForever,
  gpsDisabled,
  loadingLocation,
  locationReady,
  error,
}

class LocationPermissionState {
  final LocationPermissionUIState status;
  final LocationCoordinates? coordinates;
  final String? message;

  const LocationPermissionState({
    this.status = LocationPermissionUIState.initial,
    this.coordinates,
    this.message,
  });

  bool get isReady => status == LocationPermissionUIState.locationReady && coordinates != null;
  bool get isLoading => status == LocationPermissionUIState.checking || status == LocationPermissionUIState.loadingLocation;

  LocationPermissionState copyWith({
    LocationPermissionUIState? status,
    LocationCoordinates? coordinates,
    String? message,
  }) {
    return LocationPermissionState(
      status: status ?? this.status,
      coordinates: coordinates ?? this.coordinates,
      message: message ?? this.message,
    );
  }
}

class LocationPermissionNotifier extends StateNotifier<LocationPermissionState> {
  final ILocationService _locationService;
  final Ref _ref;

  LocationPermissionNotifier(this._locationService, this._ref)
      : super(const LocationPermissionState());

  /// Initial check to set the correct baseline UI state without prompting the user prematurely
  Future<void> checkInitialState() async {
    try {
      final permission = await _locationService.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          status: LocationPermissionUIState.permissionDeniedForever,
          message: 'Location permission is permanently denied. Please enable it in App Settings.',
        );
        return;
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final isGpsOn = await _locationService.isLocationServiceEnabled();
        if (!isGpsOn) {
          state = state.copyWith(
            status: LocationPermissionUIState.gpsDisabled,
            message: 'Location services are disabled on your device.',
          );
        } else {
          // Both permission and GPS are enabled -> acquire location seamlessly
          await _acquireLocationAndFinish();
        }
        return;
      }

      // Default initial state where permission has not been requested yet
      state = state.copyWith(
        status: LocationPermissionUIState.initial,
        message: 'QuestUP uses your location to find nearby real-world quests and verify that you have reached quest locations.',
      );
    } catch (e) {
      debugPrint('[LOCATION] Error in checkInitialState: $e');
    }
  }

  /// Triggered when the user taps "ALLOW LOCATION"
  Future<bool> requestAndAcquireLocation() async {
    state = state.copyWith(
      status: LocationPermissionUIState.checking,
      message: 'Checking location permission...',
    );

    try {
      // STEP 1: Check existing permission
      LocationPermission permission = await _locationService.checkPermission();

      // STEP 2: Request permission from OS if denied
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
      }

      // STEP 3: Handle permission result
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          status: LocationPermissionUIState.permissionDenied,
          message: 'Location permission is required to discover nearby quests.',
        );
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          status: LocationPermissionUIState.permissionDeniedForever,
          message: 'Location permission is permanently denied. Please enable it in App Settings.',
        );
        return false;
      }

      // STEP 4: Permission granted -> Check GPS / Location service status
      final isGpsOn = await _locationService.isLocationServiceEnabled();
      if (!isGpsOn) {
        state = state.copyWith(
          status: LocationPermissionUIState.gpsDisabled,
          message: 'Location services are disabled on your device.',
        );
        return false;
      }

      // STEP 5: GPS is ON -> Acquire real-time location
      return await _acquireLocationAndFinish();
    } catch (e) {
      debugPrint('[LOCATION] Exception during requestAndAcquireLocation: $e');
      state = state.copyWith(
        status: LocationPermissionUIState.error,
        message: 'Unable to get your current location. Please try again.',
      );
      return false;
    }
  }

  /// Triggered on App Lifecycle Resume (e.g. returning from Android Location Settings or App Settings)
  Future<bool> checkAndAutoResume() async {
    if (state.isReady) return true;

    try {
      debugPrint('[LOCATION] App resumed - checking permission and GPS service');
      final permission = await _locationService.checkPermission();

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final isGpsOn = await _locationService.isLocationServiceEnabled();
        if (isGpsOn) {
          debugPrint('[LOCATION] GPS is ON and Permission is Granted! Auto-acquiring position...');
          return await _acquireLocationAndFinish();
        } else {
          state = state.copyWith(
            status: LocationPermissionUIState.gpsDisabled,
            message: 'Location services are disabled on your device.',
          );
          return false;
        }
      } else if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          status: LocationPermissionUIState.permissionDeniedForever,
          message: 'Location permission is permanently denied. Please enable it in App Settings.',
        );
        return false;
      } else {
        state = state.copyWith(
          status: LocationPermissionUIState.permissionDenied,
          message: 'Location permission is required to discover nearby quests.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[LOCATION] Error during checkAndAutoResume: $e');
      return false;
    }
  }

  Future<bool> _acquireLocationAndFinish() async {
    state = state.copyWith(
      status: LocationPermissionUIState.loadingLocation,
      message: 'Acquiring current location coordinates...',
    );

    try {
      final coords = await _locationService.getCurrentLocation();

      // Save permission state to local storage
      final storage = _ref.read(localStorageServiceProvider);
      await storage.saveString(AppConstants.keyLocationPermissionGranted, 'true');

      // Update active GPS coordinates in Riverpod
      _ref.read(activeGpsCoordinatesProvider.notifier).state = coords;

      // Start quest discovery with real coordinates
      unawaited(_ref.read(questsNotifierProvider.notifier).fetchQuests(coords: coords, showLoading: false));

      state = state.copyWith(
        status: LocationPermissionUIState.locationReady,
        coordinates: coords,
        message: 'GPS Signal Locked: Lat ${coords.latitude.toStringAsFixed(4)}, Lon ${coords.longitude.toStringAsFixed(4)}',
      );

      return true;
    } catch (e) {
      debugPrint('[LOCATION] Error acquiring coordinates: $e');
      state = state.copyWith(
        status: LocationPermissionUIState.error,
        message: 'Unable to get your current location. Please ensure location is enabled and try again.',
      );
      return false;
    }
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Future<void> skipForNow() async {
    // Allows user to proceed without granting location immediately
  }
}

final locationPermissionNotifierProvider = StateNotifierProvider.autoDispose<
    LocationPermissionNotifier, LocationPermissionState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationPermissionNotifier(locationService, ref);
});
