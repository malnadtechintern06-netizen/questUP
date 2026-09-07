import 'package:flutter/foundation.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../domain/entities/quest.dart';
import '../../domain/repositories/quest_repository.dart';
import '../datasources/quest_local_datasource.dart';
import '../datasources/quest_mysql_datasource.dart';
import '../models/quest_model.dart';

class QuestRepositoryImpl implements QuestRepository {
  final IQuestLocalDataSource localDataSource;
  final IQuestMySqlDataSource mySqlDataSource;

  QuestRepositoryImpl({
    required this.localDataSource,
    required this.mySqlDataSource,
  });

  @override
  Future<List<Quest>> getQuests({
    double? userLat,
    double? userLon,
    String? userId,
  }) async {
    // 1. Fetch cached local quests (base activity + landmark presets)
    final localQuests = await localDataSource.getQuests();
    final localCount = localQuests.length;
    debugPrint('[QuestUP] Cache count: $localCount');

    // 2. Trigger dynamic location quest generation if user coordinates are provided
    if (userLat != null && userLon != null) {
      try {
        await mySqlDataSource.generateLocationQuests(
          latitude: userLat,
          longitude: userLon,
          userId: userId,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => [],
        );
      } catch (e) {
        debugPrint('[QuestUP Location Quest] Generation request error: $e');
      }
    }

    // 3. Fetch fresh remote Cloud / REST API quests from MySQL (admin + location-generated)
    List<QuestModel> remoteQuests = [];
    try {
      final fetched = await mySqlDataSource.fetchQuestsFromMySql(
        userId: userId,
        userLat: userLat,
        userLon: userLon,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => [],
      );
      remoteQuests = fetched.where((q) => q.isActive).toList();
    } catch (e) {
      debugPrint('[QuestUP] Error fetching remote quests: $e');
    }

    final apiCount = remoteQuests.length;
    debugPrint('[QuestUP] API quest count: $apiCount');
    final adminCount = remoteQuests.where((q) => q.sourceType == 'admin').length;
    debugPrint('[QuestUP Location Quest] Admin quest count: $adminCount');

    // 4. Merge both sources by unique ID (prioritize fresh remote API quests)
    final merged = <Quest>[];
    final seenIds = <String>{};

    // Add all fresh remote API quests (preserving local completion state)
    for (final q in remoteQuests) {
      if (_isUnwantedQuest(q)) continue;
      if (!seenIds.contains(q.id)) {
        seenIds.add(q.id);
        final localMatch = localQuests.where((l) => l.id == q.id).firstOrNull;
        if (localMatch != null && localMatch.isCompleted) {
          merged.add(q.copyWith(isCompleted: true));
        } else {
          merged.add(q);
        }
      }
    }

    // Add remaining local preset quests
    for (final q in localQuests) {
      if (_isUnwantedQuest(q)) continue;
      if (q.isActive && !seenIds.contains(q.id)) {
        seenIds.add(q.id);
        merged.add(q);
      }
    }

    // 5. If coordinates are provided, calculate distances for sorting
    List<Quest> finalQuests = merged;
    if (userLat != null && userLon != null) {
      finalQuests = merged.map((quest) {
        if (quest.latitude != 0.0 && quest.longitude != 0.0) {
          final distance = DistanceCalculator.calculateDistanceMeters(
            lat1: userLat,
            lon1: userLon,
            lat2: quest.latitude,
            lon2: quest.longitude,
          );
          return quest.copyWith(distanceMeters: distance);
        }
        return quest;
      }).toList();

      // Filter out location quests that are beyond 10 km (10000 meters) from user GPS
      finalQuests = finalQuests.where((quest) {
        if (quest.sourceType != 'admin' && quest.latitude != 0.0 && quest.longitude != 0.0) {
          return (quest.distanceMeters ?? double.infinity) <= 10000.0;
        }
        return true;
      }).toList();

      // Sort nearest location quests first, followed by activity quests
      finalQuests.sort((a, b) {
        final isALoc = a.latitude != 0.0 && a.longitude != 0.0;
        final isBLoc = b.latitude != 0.0 && b.longitude != 0.0;
        if (isALoc && isBLoc) {
          return (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0);
        } else if (isALoc) {
          return -1;
        } else if (isBLoc) {
          return 1;
        }
        return a.title.compareTo(b.title);
      });
    }

    final finalCount = finalQuests.length;
    debugPrint('[QuestUP Location Quest] Final quest count: $finalCount');

    // 6. Update local cache with the merged list
    try {
      await localDataSource.saveQuests(
        finalQuests.map((e) => QuestModel.fromEntity(e)).toList(),
      );
    } catch (_) {}

    return finalQuests;
  }

  @override
  Future<List<Quest>> getNearbyQuests({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 10000,
    String? userId,
  }) async {
    // 1. Trigger dynamic location quest generation
    try {
      await mySqlDataSource.generateLocationQuests(
        latitude: userLat,
        longitude: userLon,
        userId: userId,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );
    } catch (e) {
      debugPrint('[QuestUP Location Quest] Nearby generation request error: $e');
    }

    // 2. Fetch dynamic local landmarks and activity quests
    final localQuests = await localDataSource.getQuestsForLocation(
      userLat,
      userLon,
      maxRadiusMeters: maxDistanceMeters,
    );
    final localCount = localQuests.length;
    debugPrint('LOCAL QUEST COUNT = $localCount');

    // 3. Fetch fresh remote Cloud / MySQL quests
    List<QuestModel> remoteQuests = [];
    try {
      final fetched = await mySqlDataSource.fetchQuestsFromMySql(
        userId: userId,
        userLat: userLat,
        userLon: userLon,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => [],
      );
      remoteQuests = fetched.where((q) => q.isActive).toList();
    } catch (e) {
      debugPrint('[QUEST REPO] Error fetching remote quests in getNearbyQuests: $e');
    }

    final apiCount = remoteQuests.length;
    debugPrint('API QUEST COUNT = $apiCount');
    final adminCount = remoteQuests.where((q) => q.sourceType == 'admin').length;
    debugPrint('[QuestUP Location Quest] Admin quest count: $adminCount');

    final candidateQuests = <Quest>[];
    final seenIds = <String>{};

    // Prioritize all live remote API quests, preserving completion state
    for (final q in remoteQuests) {
      if (_isUnwantedQuest(q)) continue;
      if (!seenIds.contains(q.id)) {
        seenIds.add(q.id);
        final localMatch = localQuests.where((l) => l.id == q.id).firstOrNull;
        if (localMatch != null && localMatch.isCompleted) {
          candidateQuests.add(q.copyWith(isCompleted: true));
        } else {
          candidateQuests.add(q);
        }
      }
    }

    // Add local dynamic landmarks & activity quests
    for (final q in localQuests) {
      if (_isUnwantedQuest(q)) continue;
      if (!seenIds.contains(q.id)) {
        seenIds.add(q.id);
        candidateQuests.add(q);
      }
    }

    final mergedCount = candidateQuests.length;
    debugPrint('MERGED QUEST COUNT = $mergedCount');

    // 4. Calculate exact Haversine distance for location quests
    final List<Quest> calculatedQuests = candidateQuests.map((quest) {
      if (quest.latitude != 0.0 && quest.longitude != 0.0) {
        final distance = DistanceCalculator.calculateDistanceMeters(
          lat1: userLat,
          lon1: userLon,
          lat2: quest.latitude,
          lon2: quest.longitude,
        );
        return quest.copyWith(distanceMeters: distance);
      }
      return quest;
    }).toList();

    // 5. Filter: Location-based quests must be within maxDistanceMeters; activity quests (lat/lon == 0) are always included
    final filtered = calculatedQuests.where((q) {
      if (q.latitude != 0.0 && q.longitude != 0.0) {
        return (q.distanceMeters ?? double.infinity) <= maxDistanceMeters;
      }
      return true; // Activity quests always accessible
    }).toList();

    // 6. Sort: Nearest location quests first, followed by activity quests
    filtered.sort((a, b) {
      final isALocation = a.latitude != 0.0 && a.longitude != 0.0;
      final isBLocation = b.latitude != 0.0 && b.longitude != 0.0;
      if (isALocation && isBLocation) {
        return (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0);
      } else if (isALocation) {
        return -1;
      } else if (isBLocation) {
        return 1;
      }
      return a.title.compareTo(b.title);
    });

    debugPrint('[QuestUP Location Quest] Final quest count: ${filtered.length}');
    return filtered;
  }

  @override
  Future<Quest?> getQuestById(String id) async {
    final local = await localDataSource.getQuestById(id);
    if (local != null && !_isUnwantedQuest(local)) return local;

    try {
      final remoteQuests = await mySqlDataSource.fetchQuestsFromMySql().timeout(
        const Duration(seconds: 8),
        onTimeout: () => [],
      );
      for (final q in remoteQuests) {
        if (q.id == id && !_isUnwantedQuest(q)) {
          // Persist to local cache so future lookups are instant
          try {
            final all = await localDataSource.getQuests();
            if (!all.any((existing) => existing.id == q.id)) {
              await localDataSource.saveQuests([...all, q]);
            }
          } catch (_) {}
          return q;
        }
      }
    } catch (_) {}

    return null;
  }

  bool _isUnwantedQuest(Quest q) {
    final t = q.title.toLowerCase();
    final l = q.locationName.toLowerCase();
    return t.contains("d'souza") ||
        t.contains("sports complex") ||
        t.contains("#99") ||
        l.contains("d'souza");
  }

  @override
  Future<void> markQuestCompleted(String id) async {
    await localDataSource.markCompleted(id);
  }
}
