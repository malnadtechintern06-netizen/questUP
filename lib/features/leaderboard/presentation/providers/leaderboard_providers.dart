import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/features/leaderboard/data/datasources/leaderboard_local_datasource.dart';
import 'package:quest_up/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'package:quest_up/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:quest_up/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:quest_up/features/leaderboard/domain/usecases/get_leaderboard_usecase.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';

final leaderboardLocalDataSourceProvider = Provider<ILeaderboardLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return LeaderboardLocalDataSource(storage);
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final dataSource = ref.watch(leaderboardLocalDataSourceProvider);
  return LeaderboardRepositoryImpl(dataSource);
});

final getLeaderboardUseCaseProvider = Provider<GetLeaderboardUseCase>((ref) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  return GetLeaderboardUseCase(repo);
});

final leaderboardFilterProvider = StateProvider<String>((ref) => 'all_time');

final leaderboardEntriesProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final userProfile = ref.watch(userProfileNotifierProvider).value;
  final useCase = ref.watch(getLeaderboardUseCaseProvider);
  final filter = ref.watch(leaderboardFilterProvider);

  if (userProfile == null) return [];

  return await useCase(
    currentUserId: userProfile.id,
    currentUserName: userProfile.name,
    currentUserAvatar: userProfile.avatarKey,
    currentUserLevel: userProfile.level,
    currentUserXp: userProfile.currentXp + (userProfile.level - 1) * 500,
    currentUserCompletedCount: userProfile.completedQuestIds.length,
    filter: filter,
  );
});
