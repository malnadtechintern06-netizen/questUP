import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/services/location_service.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';

enum LocationPermissionUIState {
  initial,
  requesting,
  acquired,
  denied,
  permanentlyDenied,
  serviceDisabled,
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

  Future<bool> requestAndAcquireLocation() async {
    state = state.copyWith(
      status: LocationPermissionUIState.requesting,
      message: 'Checking GPS and requesting location access...',
    );

    try {
      // 1. Check if device location services are enabled
      final isGpsOn = await _locationService.isLocationServiceEnabled();
      if (!isGpsOn) {
        state = state.copyWith(
          status: LocationPermissionUIState.serviceDisabled,
          message: 'Location services are disabled on your phone. Please switch on GPS in device settings.',
        );
        return false;
      }

      // 2. Request permission from OS
      LocationPermission permission = await _locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          status: LocationPermissionUIState.denied,
          message: 'Location permission was denied. QuestUP needs your GPS to find nearby quests.',
        );
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          status: LocationPermissionUIState.permanentlyDenied,
          message: 'Location permission is permanently denied. Tap "Open App Settings" to enable.',
        );
        return false;
      }

      // 3. Acquire Real Device GPS Coordinates
      state = state.copyWith(
        status: LocationPermissionUIState.requesting,
        message: 'Acquiring real-time GPS satellite lock...',
      );

      final coords = await _locationService.getRealDeviceLocation();

      // Save permission state to local storage
      final storage = _ref.read(localStorageServiceProvider);
      await storage.saveString(AppConstants.keyLocationPermissionGranted, 'true');

      // Set active GPS coordinates and fetch quests for real user coordinates
      _ref.read(activeGpsCoordinatesProvider.notifier).state = coords;
      await _ref.read(questsNotifierProvider.notifier).fetchQuests(coords: coords);

      state = state.copyWith(
        status: LocationPermissionUIState.acquired,
        coordinates: coords,
        message: 'GPS Satellite Locked: Lat ${coords.latitude.toStringAsFixed(4)}, Lon ${coords.longitude.toStringAsFixed(4)}',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: LocationPermissionUIState.error,
        message: e.toString().replaceFirst('LocationException: ', ''),
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
    // Do not mark permission granted so user can enable GPS later
  }
}

final locationPermissionNotifierProvider = StateNotifierProvider.autoDispose<
    LocationPermissionNotifier, LocationPermissionState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationPermissionNotifier(locationService, ref);
});
