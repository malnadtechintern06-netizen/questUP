import '../../../../core/utils/distance_calculator.dart';
import '../../domain/entities/quest.dart';
import '../../domain/repositories/quest_repository.dart';
import '../datasources/quest_local_datasource.dart';
import '../datasources/quest_mysql_datasource.dart';

class QuestRepositoryImpl implements QuestRepository {
  final IQuestLocalDataSource localDataSource;
  final IQuestMySqlDataSource mySqlDataSource;

  QuestRepositoryImpl({
    required this.localDataSource,
    required this.mySqlDataSource,
  });

  @override
  Future<List<Quest>> getQuests() async {
    final local = await localDataSource.getQuests();
    final candidateQuests = List<Quest>.from(local.where((q) => q.isActive));

    // Also check MySQL in the background without blocking
    try {
      final mySqlQuests = await mySqlDataSource.fetchQuestsFromMySql().timeout(
        const Duration(milliseconds: 350),
        onTimeout: () => [],
      );
      for (final q in mySqlQuests) {
        if (q.isActive && !candidateQuests.any((existing) => existing.id == q.id)) {
          candidateQuests.add(q);
        }
      }
    } catch (_) {}

    return candidateQuests;
  }

  @override
  Future<List<Quest>> getNearbyQuests({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 50000,
  }) async {
    // 1. Fetch dynamic local landmarks and activity quests instantly
    final localQuests = await localDataSource.getQuestsForLocation(
      userLat,
      userLon,
      maxRadiusMeters: maxDistanceMeters,
    );
    final List<Quest> candidateQuests = List<Quest>.from(localQuests);

    // 2. Fetch any remote MySQL custom quests with non-blocking fast timeout
    try {
      final mySqlQuests = await mySqlDataSource.fetchQuestsFromMySql().timeout(
        const Duration(milliseconds: 350),
        onTimeout: () => [],
      );
      if (mySqlQuests.isNotEmpty) {
        for (final q in mySqlQuests) {
          if (q.isActive && !candidateQuests.any((existing) => existing.id == q.id)) {
            candidateQuests.add(q);
          }
        }
      }
    } catch (_) {}

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

    // 4. Filter: Include location quests within radius, and universal activity quests
    final filtered = calculatedQuests.where((q) {
      if (q.latitude != 0.0 && q.longitude != 0.0) {
        return (q.distanceMeters ?? double.infinity) <= maxDistanceMeters;
      }
      return true; // Universal activity quest available everywhere
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
    return await localDataSource.getQuestById(id);
  }

  @override
  Future<void> markQuestCompleted(String id) async {
    await localDataSource.markCompleted(id);
  }
}
