import '../../../../core/utils/distance_calculator.dart';
import '../../domain/entities/quest.dart';
import '../../domain/repositories/quest_repository.dart';
import '../datasources/quest_firestore_datasource.dart';
import '../datasources/quest_local_datasource.dart';

class QuestRepositoryImpl implements QuestRepository {
  final IQuestLocalDataSource localDataSource;
  final IQuestFirestoreDataSource firestoreDataSource;

  QuestRepositoryImpl({
    required this.localDataSource,
    required this.firestoreDataSource,
  });

  @override
  Future<List<Quest>> getQuests() async {
    // 1. Try remote Firestore first
    final firestoreQuests = await firestoreDataSource.fetchQuestsFromFirestore();
    if (firestoreQuests.isNotEmpty) {
      return firestoreQuests.where((q) => q.isActive).toList();
    }

    // 2. Fallback to local storage
    final local = await localDataSource.getQuests();
    return local.where((q) => q.isActive).toList();
  }

  @override
  Future<List<Quest>> getNearbyQuests({
    required double userLat,
    required double userLon,
    double maxDistanceMeters = 50000,
  }) async {
    List<Quest> candidateQuests = [];

    // 1. Check if Firestore has active quests in the area
    final firestoreQuests = await firestoreDataSource.fetchQuestsFromFirestore();
    if (firestoreQuests.isNotEmpty) {
      // Check if any firestore quest is actually near the user
      final nearbyFirestore = firestoreQuests.where((q) {
        if (!q.isActive) return false;
        final distance = DistanceCalculator.calculateDistanceMeters(
          lat1: userLat,
          lon1: userLon,
          lat2: q.latitude,
          lon2: q.longitude,
        );
        return distance <= maxDistanceMeters;
      }).toList();

      if (nearbyFirestore.isNotEmpty) {
        candidateQuests = nearbyFirestore;
      }
    }

    // 2. If no nearby Firestore quests, use local dynamic location-anchored quests
    if (candidateQuests.isEmpty) {
      candidateQuests = await localDataSource.getQuestsForLocation(
        userLat,
        userLon,
        maxRadiusMeters: maxDistanceMeters,
      );
    }

    // 3. Calculate exact Haversine distance for location quests, retain universal activity quests
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

    // 4. Filter: Include location quests within radius, and all universal activity quests
    final filtered = calculatedQuests.where((q) {
      if (q.latitude != 0.0 && q.longitude != 0.0) {
        return (q.distanceMeters ?? double.infinity) <= maxDistanceMeters;
      }
      return true; // Universal activity quest available everywhere
    }).toList();

    // 5. Sort: Nearest location-based quests first, followed by activity quests
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
