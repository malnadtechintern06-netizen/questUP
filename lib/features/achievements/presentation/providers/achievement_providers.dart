import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/features/achievements/data/datasources/achievement_local_datasource.dart';
import 'package:quest_up/features/achievements/data/repositories/achievement_repository_impl.dart';
import 'package:quest_up/features/achievements/domain/entities/achievement.dart';
import 'package:quest_up/features/achievements/domain/repositories/achievement_repository.dart';
import 'package:quest_up/features/achievements/domain/usecases/get_achievements_usecase.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';

final achievementLocalDataSourceProvider = Provider<IAchievementLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return AchievementLocalDataSource(storage);
});

final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  final dataSource = ref.watch(achievementLocalDataSourceProvider);
  return AchievementRepositoryImpl(dataSource);
});

final getAchievementsUseCaseProvider = Provider<GetAchievementsUseCase>((ref) {
  final repo = ref.watch(achievementRepositoryProvider);
  return GetAchievementsUseCase(repo);
});

class AchievementsNotifier extends StateNotifier<AsyncValue<List<Achievement>>> {
  final GetAchievementsUseCase _getAchievementsUseCase;

  AchievementsNotifier(this._getAchievementsUseCase)
      : super(const AsyncValue.loading()) {
    loadAchievements();
  }

  Future<void> loadAchievements() async {
    state = const AsyncValue.loading();
    try {
      final list = await _getAchievementsUseCase();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final achievementsNotifierProvider =
    StateNotifierProvider<AchievementsNotifier, AsyncValue<List<Achievement>>>((ref) {
  final useCase = ref.watch(getAchievementsUseCaseProvider);
  return AchievementsNotifier(useCase);
});
