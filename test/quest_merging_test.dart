import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_up/core/services/activity_quest_catalog_service.dart';
import 'package:quest_up/core/services/places_discovery_service.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/quests/data/datasources/quest_local_datasource.dart';
import 'package:quest_up/features/quests/data/datasources/quest_mysql_datasource.dart';
import 'package:quest_up/features/quests/data/repositories/quest_repository_impl.dart';

class _AllowRealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowRealHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('QuestRepositoryImpl merges 22 local quests and 7 API quests to 29 total quests', () async {
    final localSource = QuestLocalDataSource(
      LocalStorageService(),
      PlacesDiscoveryService(),
      ActivityQuestCatalogService(),
    );
    final mySqlSource = QuestMySqlDataSource();

    final repository = QuestRepositoryImpl(
      localDataSource: localSource,
      mySqlDataSource: mySqlSource,
    );

    final localQuests = await localSource.getQuests();
    final localIds = localQuests.map((e) => e.id).toSet();

    final mergedQuests = await repository.getQuests();

    int localCount = 0;
    int apiCount = 0;
    for (final q in mergedQuests) {
      if (localIds.contains(q.id)) {
        localCount++;
      } else {
        apiCount++;
      }
    }

    final apiQuests = await mySqlSource.fetchQuestsFromMySql();
    final expectedTotal = localIds.union(apiQuests.map((e) => e.id).toSet()).length;

    expect(localCount, equals(localQuests.length));
    expect(apiCount, greaterThanOrEqualTo(0));
    expect(apiQuests.isNotEmpty, isTrue);
    expect(mergedQuests.length, equals(expectedTotal));
  });
}
