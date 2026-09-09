import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_up/core/services/location_service.dart';
import 'package:quest_up/core/services/notification_service.dart';
import 'package:quest_up/core/services/places_discovery_service.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/features/notifications/domain/entities/app_notification.dart';
import 'package:quest_up/features/notifications/presentation/providers/notification_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/domain/entities/shared_quest.dart';
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
final maxRadiusFilterMetersProvider = StateProvider<double>((ref) => 10000.0); // 10km default

// Latest Coordinates Provider (updated by GPS and simulation)
final activeGpsCoordinatesProvider = StateProvider<LocationCoordinates?>((ref) => null);

// Check if location services and permissions are currently active
final isLocationEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final activeGps = ref.watch(activeGpsCoordinatesProvider);
  if (activeGps != null) return true;
  final service = ref.watch(locationServiceProvider);
  return await service.isLocationEnabledAndPermitted();
});

// Quests List Notifier with live GPS tracking, nearest-first sorting, periodic background sync, and new quest notification dispatch
class QuestsNotifier extends StateNotifier<AsyncValue<List<Quest>>> {
  final GetNearbyQuestsUseCase getNearbyQuestsUseCase;
  final GetQuestsUseCase getQuestsUseCase;
  final ILocationService locationService;
  final Ref ref;
  StreamSubscription<LocationCoordinates>? _locationSubscription;
  LocationCoordinates? _lastFetchedLocation;
  Completer<void>? _ongoingFetch;
  Timer? _periodicSyncTimer;
  Set<String> _seenQuestIds = {};
  bool _isInitializedSeenIds = false;

  QuestsNotifier({
    required this.getNearbyQuestsUseCase,
    required this.getQuestsUseCase,
    required this.locationService,
    required this.ref,
  }) : super(const AsyncValue.loading()) {
    _initQuestsWithLocationCheck();
    _startLocationTracking();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    // Periodically poll backend for newly uploaded quests every 25 seconds
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      fetchQuests(showLoading: false);
    });
  }

  Future<void> _initSeenQuestIds(List<Quest> initialQuests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('seen_quest_ids_v1');
      if (savedIds != null && savedIds.isNotEmpty) {
        _seenQuestIds = savedIds.toSet();
      } else {
        // First run: seed existing quests so we don't bombard user with all quests initially
        _seenQuestIds = initialQuests.map((q) => q.id).toSet();
        await prefs.setStringList('seen_quest_ids_v1', _seenQuestIds.toList());
      }
      _isInitializedSeenIds = true;
    } catch (e) {
      debugPrint('[QUEST NOTIFIER] Error initializing seen quest IDs: $e');
      _seenQuestIds = initialQuests.map((q) => q.id).toSet();
      _isInitializedSeenIds = true;
    }
  }

  Future<void> _handleNewQuestsDetection(List<Quest> quests) async {
    if (!_isInitializedSeenIds) {
      await _initSeenQuestIds(quests);
      return;
    }

    // Identify newly detected quests that were not previously seen
    final newQuests =
        quests.where((q) => !_seenQuestIds.contains(q.id)).toList();

    if (newQuests.isNotEmpty) {
      for (final newQuest in newQuests) {
        _seenQuestIds.add(newQuest.id);
        debugPrint('[QuestUP] New quest received: ${newQuest.title} (${newQuest.id})');

        // 1. Dispatch Native System Notification to Phone's Status Bar / Shade
        try {
          await NotificationService.instance.showNewQuestNotification(newQuest);
        } catch (e) {
          debugPrint(
              '[QUEST NOTIFIER] Error showing status-bar notification: $e');
        }

        // 2. Add In-App Notification entry to NotificationsNotifier
        try {
          final rewardText =
              '+${newQuest.xpReward} XP • +${newQuest.coinReward} Coins';
          final locText = newQuest.locationName.isNotEmpty
              ? ' at ${newQuest.locationName}'
              : '';

          ref.read(notificationsNotifierProvider.notifier).addNotification(
                AppNotification(
                  id: 'notif-new-quest-${newQuest.id}',
                  title: '⚔️ New Quest: ${newQuest.title}',
                  message:
                      'New real-world adventure available$locText! Rewards: $rewardText. Tap to explore details.',
                  timestamp: DateTime.now(),
                  type: NotificationType.quest,
                  isRead: false,
                  routeTarget: '/quests/${newQuest.id}',
                  actionLabel: 'Explore Quest',
                ),
              );
        } catch (e) {
          debugPrint('[QUEST NOTIFIER] Error adding in-app notification: $e');
        }
      }

      // Persist updated seen quest IDs
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('seen_quest_ids_v1', _seenQuestIds.toList());
      } catch (_) {}
    }
  }

  String? _getCurrentUserId() {
    try {
      final profile = ref.read(userProfileNotifierProvider).value;
      if (profile != null && profile.id.isNotEmpty && profile.id != 'guest_player') {
        return profile.id;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _initQuestsWithLocationCheck() async {
    // 1. Immediately emit local/cached quests in 0ms so all cards and images appear instantly!
    try {
      final localSource = ref.read(questLocalDataSourceProvider);
      final initialQuests = await localSource.getQuests();
      if (initialQuests.isNotEmpty) {
        state = AsyncValue.data(initialQuests);
        _initSeenQuestIds(initialQuests);
      }
    } catch (_) {}

    // 2. Fetch live quests & real GPS in the background smoothly without blank screen
    try {
      final isLocationReady = await locationService.isLocationEnabledAndPermitted();
      if (isLocationReady) {
        await fetchQuests(showLoading: false);
      } else {
        ref.read(activeGpsCoordinatesProvider.notifier).state = null;
        debugPrint('[QuestUP GPS] Location permission not granted or service disabled');
        ref.read(notificationsNotifierProvider.notifier).addNotification(
          AppNotification(
            id: 'notif-location-permission',
            title: '📍 Location Access Needed',
            message: 'Enable location permission to discover personalized landmark quests near you!',
            timestamp: DateTime.now(),
            type: NotificationType.system,
            isRead: false,
          ),
        );
        final quests = await getQuestsUseCase(userId: _getCurrentUserId());
        state = AsyncValue.data(quests);
        await _handleNewQuestsDetection(quests);
      }
    } catch (_) {
      try {
        final quests = await getQuestsUseCase(userId: _getCurrentUserId());
        state = AsyncValue.data(quests);
        await _handleNewQuestsDetection(quests);
      } catch (e, st) {
        if (!state.hasValue) {
          state = AsyncValue.error(e, st);
        }
      }
    }
  }

  void _startLocationTracking() {
    _locationSubscription = locationService.locationStream.listen(
      (newCoords) {
        ref.read(activeGpsCoordinatesProvider.notifier).state = newCoords;
        debugPrint('[QuestUP GPS] Current latitude: ${newCoords.latitude}');
        debugPrint('[QuestUP GPS] Current longitude: ${newCoords.longitude}');

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

        if (distanceMoved >= 500.0) {
          // Significant location change (>=500m): re-fetch real nearby landmarks for new area
          _lastFetchedLocation = newCoords;
          fetchQuests(coords: newCoords, showLoading: false);
        } else {
          // Minor movement (<500m): smoothly recalculate distances without reloading UI
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
    if (_ongoingFetch != null) {
      return _ongoingFetch!.future;
    }
    final completer = Completer<void>();
    _ongoingFetch = completer;

    if (showLoading && (state.valueOrNull == null || state.valueOrNull!.isEmpty)) {
      state = const AsyncValue.loading();
    }

    final sw = Stopwatch()..start();
    try {
      LocationCoordinates? loc;
      if (coords != null) {
        loc = coords;
      } else {
        final isReady = await locationService.isLocationEnabledAndPermitted();
        if (isReady) {
          loc = await locationService.getCurrentLocation();
        }
      }

      List<Quest> quests;
      if (loc != null) {
        _lastFetchedLocation = loc;
        ref.read(activeGpsCoordinatesProvider.notifier).state = loc;
        debugPrint('[QuestUP GPS] Current latitude: ${loc.latitude}');
        debugPrint('[QuestUP GPS] Current longitude: ${loc.longitude}');
      } else {
        ref.read(activeGpsCoordinatesProvider.notifier).state = null;
      }
      quests = await getQuestsUseCase(
        userLat: loc?.latitude,
        userLon: loc?.longitude,
        userId: _getCurrentUserId(),
      );

      debugPrint('[QUEST PROVIDER] Updated quest count: ${quests.length}');
      debugPrint('[QUEST PROVIDER] Refresh completed in ${sw.elapsedMilliseconds}ms');
      state = AsyncValue.data(quests);

      // Check for newly uploaded quests and dispatch phone notification bar alert
      await _handleNewQuestsDetection(quests);

      if (quests.isNotEmpty && loc != null) {
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
            routeTarget: '/quests/${nearest.id}',
            actionLabel: 'View Quests',
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[QUEST PROVIDER] Error fetching quests: $e');
      if (state.valueOrNull == null || state.valueOrNull!.isEmpty) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _ongoingFetch = null;
      completer.complete();
    }
  }

  Future<void> refreshQuests({bool showLoading = false}) async {
    await fetchQuests(showLoading: showLoading);
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
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}

final questsNotifierProvider =
    StateNotifierProvider<QuestsNotifier, AsyncValue<List<Quest>>>((ref) {
  final getNearby = ref.watch(getNearbyQuestsUseCaseProvider);
  final getQuests = ref.watch(getQuestsUseCaseProvider);
  final locationService = ref.watch(locationServiceProvider);
  return QuestsNotifier(
    getNearbyQuestsUseCase: getNearby,
    getQuestsUseCase: getQuests,
    locationService: locationService,
    ref: ref,
  );
});

// Filtered quests provider based on category and search query
final filteredQuestsProvider = Provider<List<Quest>>((ref) {
  final questsAsync = ref.watch(questsNotifierProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final rawQuery = ref.watch(searchQueryProvider);
  final cleanQuery = rawQuery.trim().toLowerCase();

  return questsAsync.when(
    data: (quests) {
      return quests.where((q) {
        if (q.isCompleted) return false;
        final matchesCat = selectedCategory == null || q.category == selectedCategory;
        if (cleanQuery.isEmpty) return matchesCat;

        final searchSpace = [
          q.title,
          q.locationName,
          q.description,
          q.category.name,
          q.placeAddress ?? '',
          q.originLocationName ?? '',
          q.storyline,
          q.historicalFact ?? '',
          q.sourceType,
          q.difficulty.name,
          q.verificationType.name,
        ].join(' ').toLowerCase();

        final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
        final matchesQuery = tokens.every((token) => searchSpace.contains(token));
        return matchesCat && matchesQuery;
      }).toList();
    },

    loading: () => [],
    error: (err, stack) => [],
  );
});

// Radar & nearby quests provider (filtered strictly by max distance)
final nearbyQuestsProvider = Provider<List<Quest>>((ref) {
  final questsAsync = ref.watch(questsNotifierProvider);
  final maxRadius = ref.watch(maxRadiusFilterMetersProvider);

  return questsAsync.when(
    data: (quests) {
      return quests.where((q) {
        if (q.latitude != 0.0 && q.longitude != 0.0) {
          return (q.distanceMeters ?? double.infinity) <= maxRadius;
        }
        return true; // Activity quests always accessible
      }).toList();
    },
    loading: () => [],
    error: (err, stack) => [],
  );
});

// Shared Quests Provider for current user (incoming and outgoing squad co-op assists)
final sharedQuestsProvider = FutureProvider.autoDispose<List<SharedQuest>>((ref) async {
  final profile = ref.watch(userProfileNotifierProvider).valueOrNull;
  if (profile == null || profile.id.isEmpty || profile.id == 'guest_player') return [];
  final repo = ref.watch(questRepositoryProvider);
  return await repo.getSharedQuests(userId: profile.id);
});

// Single Quest Provider by ID
final singleQuestProvider =
    FutureProvider.family<Quest?, String>((ref, questId) async {
  Quest? foundQuest;

  // 1. Instant check in memory (from questsNotifierProvider where user tapped the quest card)
  final inMemoryQuests = ref.watch(questsNotifierProvider).valueOrNull;
  if (inMemoryQuests != null && inMemoryQuests.isNotEmpty) {
    foundQuest = inMemoryQuests.where((q) => q.id == questId).firstOrNull;
  }

  // 2. Fetch from repository (checks local storage cache first, then MySQL if needed)
  if (foundQuest == null) {
    final getById = ref.watch(getQuestByIdUseCaseProvider);
    foundQuest = await getById(questId);
  }

  // 3. Fallback: Force refresh all quests from repository in case new quest was added recently
  if (foundQuest == null) {
    try {
      final profile = ref.read(userProfileNotifierProvider).value;
      final userId = (profile != null && profile.id.isNotEmpty && profile.id != 'guest_player') ? profile.id : null;
      final allQuests = await ref.read(getQuestsUseCaseProvider).call(userId: userId);
      foundQuest = allQuests.where((q) => q.id == questId).firstOrNull;
    } catch (_) {}
  }

  if (foundQuest == null) return null;

  // 4. Augment with Squad Co-Op shared metadata if another player shared it with the current user
  try {
    final sharedList = ref.watch(sharedQuestsProvider).valueOrNull;
    if (sharedList != null && sharedList.isNotEmpty) {
      final myProfile = ref.read(userProfileNotifierProvider).valueOrNull;
      final myId = myProfile?.id ?? '';
      final incomingShare = sharedList.where((sq) => sq.questId == questId && sq.receiverId == myId).firstOrNull;
      if (incomingShare != null) {
        return foundQuest.copyWith(
          isSharedQuest: true,
          sharedByUserId: incomingShare.senderId,
          sharedByUserName: incomingShare.senderName,
          sharedByUserTag: incomingShare.senderTag,
          sharedStatus: incomingShare.status.name,
        );
      }
    }
  } catch (_) {}

  return foundQuest;
});
