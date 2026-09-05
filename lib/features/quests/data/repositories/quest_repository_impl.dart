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
  Future<List<Quest>> getQuests() async {
    // 1. Fetch all local quests (22 quests)
    final localQuests = await localDataSource.getQuests();
    final localCount = localQuests.length;
    debugPrint('LOCAL QUEST COUNT = $localCount');

    // 2. Fetch fresh remote Cloud / REST API quests (7 quests)
    List<QuestModel> remoteQuests = [];
    try {
      final fetched = await mySqlDataSource.fetchQuestsFromMySql().timeout(
        const Duration(seconds: 8),
        onTimeout: () => [],
      );
      remoteQuests = fetched.where((q) => q.isActive).toList();
    } catch (e) {
      debugPrint('[QUEST REPO] Error fetching remote quests: $e');
    }

    final apiCount = remoteQuests.length;
    debugPrint('API QUEST COUNT = $apiCount');

    // 3. Merge both sources by unique ID (no duplicates, 22 local + 7 API = 29 merged)
    final merged = <Quest>[];
    final seenIds = <String>{};

    // Add all fresh remote API quests (preserving local completion state)
    for (final q in remoteQuests) {
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

    // Add all local quests (never dropped)
    for (final q in localQuests) {
      if (q.isActive && !seenIds.contains(q.id)) {
        seenIds.add(q.id);
        merged.add(q);
      }
    }

    final mergedCount = merged.length;
    debugPrint('MERGED QUEST COUNT = $mergedCount');

    // 4. Update local cache with the merged list
    try {
      await localDataSource.saveQuests(
        merged.map((e) => QuestModel.fromEntity(e)).toList(),
      );
    } catch (_) {}

    return merged;
  }

  @override
  Future<List<Quest>> getNearbyQuests({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 50000,
  }) async {
    // 1. Fetch dynamic local landmarks and activity quests (22 local)
    final localQuests = await localDataSource.getQuestsForLocation(
      userLat,
      userLon,
      maxRadiusMeters: maxDistanceMeters,
    );
    final localCount = localQuests.length;
    debugPrint('LOCAL QUEST COUNT = $localCount');

    // 2. Fetch fresh remote Cloud / MySQL custom quests (7 API)
    List<QuestModel> remoteQuests = [];
    try {
      final fetched = await mySqlDataSource.fetchQuestsFromMySql().timeout(
        const Duration(seconds: 8),
        onTimeout: () => [],
      );
      remoteQuests = fetched.where((q) => q.isActive).toList();
    } catch (e) {
      debugPrint('[QUEST REPO] Error fetching remote quests in getNearbyQuests: $e');
    }

    final apiCount = remoteQuests.length;
    debugPrint('API QUEST COUNT = $apiCount');

    final candidateQuests = <Quest>[];
    final seenIds = <String>{};

    // Prioritize all live remote API quests, preserving completion state
    for (final q in remoteQuests) {
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
      if (!seenIds.contains(q.id)) {
        seenIds.add(q.id);
        candidateQuests.add(q);
      }
    }

    final mergedCount = candidateQuests.length;
    debugPrint('MERGED QUEST COUNT = $mergedCount');

    // 3. Calculate exact Haversine distance for location quests
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

    // 4. Filter: All custom API quests & activity quests are always accessible in directory;
    // only auto-generated local dynamic landmarks respect the radar radius boundary
    final filtered = calculatedQuests.where((q) {
      final isAutoGeneratedLocal = q.id.startsWith('local_');
      if (isAutoGeneratedLocal && q.latitude != 0.0 && q.longitude != 0.0) {
        return (q.distanceMeters ?? double.infinity) <= maxDistanceMeters;
      }
      return true; // Online admin quests & activity quests always included
    }).toList();

    // 5. Sort: Nearest location quests first, followed by activity quests
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

    return filtered;
  }

  @override
  Future<Quest?> getQuestById(String id) async {
    final local = await localDataSource.getQuestById(id);
    if (local != null) return local;

    try {
      final remoteQuests = await mySqlDataSource.fetchQuestsFromMySql().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
      for (final q in remoteQuests) {
        if (q.id == id) return q;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> markQuestCompleted(String id) async {
    await localDataSource.markCompleted(id);
  }
}
