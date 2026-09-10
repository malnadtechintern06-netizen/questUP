import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/core/services/mysql_database_service.dart';
import 'package:quest_up/features/leaderboard/data/datasources/leaderboard_local_datasource.dart';
import 'package:quest_up/features/leaderboard/data/datasources/leaderboard_remote_datasource.dart';
import 'package:quest_up/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'package:quest_up/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:quest_up/features/leaderboard/domain/usecases/get_leaderboard_usecase.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/friends/presentation/providers/friends_providers.dart';
import 'package:quest_up/features/verification/presentation/providers/verification_providers.dart';

final leaderboardRemoteDataSourceProvider = Provider<ILeaderboardRemoteDataSource>((ref) {
  final dbService = MySqlDatabaseService.instance;
  return LeaderboardRemoteDataSource(dbService);
});

final leaderboardLocalDataSourceProvider = Provider<ILeaderboardLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return LeaderboardLocalDataSource(storage);
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepositoryImpl>((ref) {
  final remoteDataSource = ref.watch(leaderboardRemoteDataSourceProvider);
  final localDataSource = ref.watch(leaderboardLocalDataSourceProvider);
  final friendsRepo = ref.watch(friendsRepositoryProvider);
  final verificationData = ref.watch(verificationLocalDataSourceProvider);

  return LeaderboardRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    friendsRepository: friendsRepo,
    verificationLocalDataSource: verificationData,
  );
});

final getLeaderboardUseCaseProvider = Provider<GetLeaderboardUseCase>((ref) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  return GetLeaderboardUseCase(repo);
});

final leaderboardFilterProvider = StateProvider<String>((ref) => 'all_time');

// Persistent cache provider for each filter to eliminate shimmer reload delays
final leaderboardByFilterProvider = FutureProvider.family<List<LeaderboardEntry>, String>((ref, filter) async {
  final useCase = ref.watch(getLeaderboardUseCaseProvider);
  final userProfile = ref.watch(userProfileNotifierProvider).value;

  final currentUserId = userProfile?.id ?? '';
  final currentUserName = userProfile?.name ?? 'Explorer';
  final currentUserAvatar = userProfile?.avatarKey ?? 'avatar_ranger';
  final currentUserLevel = userProfile?.level ?? 1;
  final currentUserXp = userProfile != null
      ? (userProfile.currentXp + (userProfile.level - 1) * 500)
      : 0;
  final currentUserCompletedCount = userProfile?.completedQuestIds.length ?? 0;

  return await useCase(
    currentUserId: currentUserId,
    currentUserName: currentUserName,
    currentUserAvatar: currentUserAvatar,
    currentUserLevel: currentUserLevel,
    currentUserXp: currentUserXp,
    currentUserCompletedCount: currentUserCompletedCount,
    filter: filter,
  );
});

final leaderboardEntriesProvider = Provider<AsyncValue<List<LeaderboardEntry>>>((ref) {
  final currentFilter = ref.watch(leaderboardFilterProvider);
  return ref.watch(leaderboardByFilterProvider(currentFilter));
});
