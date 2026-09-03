import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/core/services/location_service.dart';
import 'package:quest_up/core/services/places_discovery_service.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/notifications/domain/entities/app_notification.dart';
import 'package:quest_up/features/notifications/presentation/providers/notification_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/domain/repositories/quest_repository.dart';
import 'package:quest_up/features/quests/domain/usecases/get_nearby_quests_usecase.dart';
import 'package:quest_up/features/quests/domain/usecases/get_quest_by_id_usecase.dart';
import 'package:quest_up/features/quests/domain/usecases/get_quests_usecase.dart';

// Services
final locationServiceProvider = Provider<ILocationService>((ref) {
  return LocationService();
});

final placesDiscoveryServiceProvider = Provider<IPlacesDiscoveryService>((ref) {
  return PlacesDiscoveryService();
});

// Live Location Stream Provider
final liveLocationStreamProvider = StreamProvider.autoDispose<LocationCoordinates>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.locationStream;
});

// Current Location State Provider
final currentLocationProvider = FutureProvider.autoDispose<LocationCoordinates>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.getCurrentLocation();
});

// Live Reverse-Geocoded Location Details Provider
final liveLocationDetailsProvider = FutureProvider.autoDispose<LocationAddressDetails?>((ref) async {
  final coords = ref.watch(activeGpsCoordinatesProvider);
  if (coords == null) return null;
  final discovery = ref.watch(placesDiscoveryServiceProvider);
  return await discovery.getLiveLocationDetails(
    coords.latitude,
    coords.longitude,
    accuracy: coords.accuracy,
  );
});

// Data Source Providers
final questLocalDataSourceProvider = Provider<IQuestLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final discovery = ref.watch(placesDiscoveryServiceProvider);
  return QuestLocalDataSource(storage, discovery);
});

final questMySqlDataSourceProvider = Provider<IQuestMySqlDataSource>((ref) {
  return QuestMySqlDataSource();
});

// Repository Provider
final questRepositoryProvider = Provider<QuestRepository>((ref) {
  final localDataSource = ref.watch(questLocalDataSourceProvider);
  final mySqlDataSource = ref.watch(questMySqlDataSourceProvider);
  return QuestRepositoryImpl(
    localDataSource: localDataSource,
    mySqlDataSource: mySqlDataSource,
  );
});

// Use Cases
final getQuestsUseCaseProvider = Provider<GetQuestsUseCase>((ref) {
  final repo = ref.watch(questRepositoryProvider);
  return GetQuestsUseCase(repo);
});

final getNearbyQuestsUseCaseProvider = Provider<GetNearbyQuestsUseCase>((ref) {
  final repo = ref.watch(questRepositoryProvider);
  return GetNearbyQuestsUseCase(repo);
});

final getQuestByIdUseCaseProvider = Provider<GetQuestByIdUseCase>((ref) {
  final repo = ref.watch(questRepositoryProvider);
  return GetQuestByIdUseCase(repo);
});

// Filter & Category state
final selectedCategoryProvider = StateProvider<QuestCategory?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final maxRadiusFilterMetersProvider = StateProvider<double>((ref) => 50000.0); // 50km default

// Latest Coordinates Provider (updated by GPS and simulation)
final activeGpsCoordinatesProvider = StateProvider<LocationCoordinates?>((ref) => null);

// Check if location services and permissions are currently active
final isLocationEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final activeGps = ref.watch(activeGpsCoordinatesProvider);
  if (activeGps != null) return true;
  final service = ref.watch(locationServiceProvider);
  return await service.isLocationEnabledAndPermitted();
});

// Quests List Notifier with live GPS tracking, nearest-first sorting, and manual refresh
class QuestsNotifier extends StateNotifier<AsyncValue<List<Quest>>> {
  final GetNearbyQuestsUseCase getNearbyQuestsUseCase;
  final ILocationService locationService;
  final Ref ref;
  StreamSubscription<LocationCoordinates>? _locationSubscription;
  LocationCoordinates? _lastFetchedLocation;
  bool _isFetching = false;

  QuestsNotifier({
    required this.getNearbyQuestsUseCase,
    required this.locationService,
    required this.ref,
  }) : super(const AsyncValue.loading()) {
    _initQuestsWithLocationCheck();
    _startLocationTracking();
  }

  Future<void> _initQuestsWithLocationCheck() async {
    try {
      final isLocationReady = await locationService.isLocationEnabledAndPermitted();
      if (isLocationReady) {
        // Location is enabled on device -> fetch quests for real location
        await fetchQuests(showLoading: true);
      } else {
        // Location is not active -> quests remain unloaded until location is enabled
        ref.read(activeGpsCoordinatesProvider.notifier).state = null;
        state = const AsyncValue.data([]);
      }
    } catch (_) {
      ref.read(activeGpsCoordinatesProvider.notifier).state = null;
      state = const AsyncValue.data([]);
    }
  }

  void _startLocationTracking() {
    _locationSubscription = locationService.locationStream.listen(
      (newCoords) {
        ref.read(activeGpsCoordinatesProvider.notifier).state = newCoords;

        if (_lastFetchedLocation == null) {
          fetchQuests(coords: newCoords, showLoading: false);
          return;
        }

        final distanceMoved = DistanceCalculator.calculateDistanceMeters(
          lat1: _lastFetchedLocation!.latitude,
          lon1: _lastFetchedLocation!.longitude,
          lat2: newCoords.latitude,
          lon2: newCoords.longitude,
        );

        if (distanceMoved >= 150.0) {
          // Significant location change (>=150m): re-fetch real nearby landmarks for new area
          _lastFetchedLocation = newCoords;
          fetchQuests(coords: newCoords, showLoading: false);
        } else {
          // Minor movement: smoothly recalculate distances without reloading UI
          _updateLiveDistances(newCoords);
        }
      },
      onError: (_) {},
    );
  }

  void _updateLiveDistances(LocationCoordinates coords) {
    final currentList = state.valueOrNull;
    if (currentList == null || currentList.isEmpty) return;

    final updated = currentList.map((quest) {
      final distance = DistanceCalculator.calculateDistanceMeters(
        lat1: coords.latitude,
        lon1: coords.longitude,
        lat2: quest.latitude,
        lon2: quest.longitude,
      );
      return quest.copyWith(distanceMeters: distance);
    }).toList();

    updated.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    state = AsyncValue.data(updated);
  }

  Future<void> fetchQuests({
    LocationCoordinates? coords,
    bool showLoading = true,
  }) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoading && (state.valueOrNull == null || state.valueOrNull!.isEmpty)) {
      state = const AsyncValue.loading();
    }

    final sw = Stopwatch()..start();
    try {
      LocationCoordinates loc;
      if (coords != null) {
        loc = coords;
      } else {
        final isReady = await locationService.isLocationEnabledAndPermitted();
        if (!isReady) {
          ref.read(activeGpsCoordinatesProvider.notifier).state = null;
          state = const AsyncValue.data([]);
          _isFetching = false;
          return;
        }
        loc = await locationService.getCurrentLocation();
      }

      _lastFetchedLocation = loc;
      ref.read(activeGpsCoordinatesProvider.notifier).state = loc;

      final maxRadius = ref.read(maxRadiusFilterMetersProvider);
      final quests = await getNearbyQuestsUseCase(
        userLat: loc.latitude,
        userLon: loc.longitude,
        maxDistanceMeters: maxRadius,
      );

      debugPrint('[QUESTUP] Quests refreshed in ${sw.elapsedMilliseconds}ms: ${quests.length} quests displayed.');
      state = AsyncValue.data(quests);

      if (quests.isNotEmpty) {
        final nearest = quests.first;
        final distText = (nearest.distanceMeters != null)
            ? ' (${(nearest.distanceMeters!).round()}m away)'
            : '';
        ref.read(notificationsNotifierProvider.notifier).addNotification(
          AppNotification(
            id: 'notif-quest-${nearest.id}',
            title: 'Nearby Quest: ${nearest.title}',
            message: 'A quest is available at ${nearest.locationName}$distText. Tap to explore!',
            timestamp: DateTime.now(),
            type: NotificationType.quest,
            isRead: false,
            routeTarget: '/quests',
            actionLabel: 'View Quests',
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[QUESTUP] Error fetching quests: $e');
      if (state.valueOrNull == null || state.valueOrNull!.isEmpty) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refreshLocationAndQuests() async {
    await fetchQuests(showLoading: true);
  }

  void simulateLocation(double lat, double lon) async {
    locationService.setSimulatedLocation(lat, lon);
    await fetchQuests(showLoading: true);
  }

  void resetSimulatedLocation() async {
    locationService.clearSimulatedLocation();
    await fetchQuests(showLoading: true);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

final questsNotifierProvider =
    StateNotifierProvider<QuestsNotifier, AsyncValue<List<Quest>>>((ref) {
  final getNearby = ref.watch(getNearbyQuestsUseCaseProvider);
  final locationService = ref.watch(locationServiceProvider);
  return QuestsNotifier(
    getNearbyQuestsUseCase: getNearby,
    locationService: locationService,
    ref: ref,
  );
});

// Filtered quests provider based on category and search query
final filteredQuestsProvider = Provider<List<Quest>>((ref) {
  final questsAsync = ref.watch(questsNotifierProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();

  return questsAsync.when(
    data: (quests) {
      return quests.where((q) {
        if (q.isCompleted) return false;
        final matchesCat = selectedCategory == null || q.category == selectedCategory;
        final matchesQuery = query.isEmpty ||
            q.title.toLowerCase().contains(query) ||
            q.locationName.toLowerCase().contains(query) ||
            q.description.toLowerCase().contains(query);
        return matchesCat && matchesQuery;
      }).toList();
    },

    loading: () => [],
    error: (err, stack) => [],
  );
});

// Single Quest Provider by ID
final singleQuestProvider =
    FutureProvider.family<Quest?, String>((ref, questId) async {
  final getById = ref.watch(getQuestByIdUseCaseProvider);
  return await getById(questId);
});
