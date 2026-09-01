import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/datasources/user_local_datasource.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/get_user_profile_usecase.dart';
import '../../domain/usecases/update_user_profile_usecase.dart';

// Storage Provider
final localStorageServiceProvider = Provider<ILocalStorageService>((ref) {
  return LocalStorageService();
});

// Data Source Provider
final userLocalDataSourceProvider = Provider<IUserLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return UserLocalDataSource(storage);
});

// Repository Provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dataSource = ref.watch(userLocalDataSourceProvider);
  return UserRepositoryImpl(dataSource);
});

// Use Cases Providers
final getUserProfileUseCaseProvider = Provider<GetUserProfileUseCase>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return GetUserProfileUseCase(repo);
});

final updateUserProfileUseCaseProvider = Provider<UpdateUserProfileUseCase>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return UpdateUserProfileUseCase(repo);
});

// State Notifier for User Profile
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final GetUserProfileUseCase _getUserProfileUseCase;
  final UpdateUserProfileUseCase _updateUserProfileUseCase;
  final UserRepository _userRepository;

  UserProfileNotifier(
    this._getUserProfileUseCase,
    this._updateUserProfileUseCase,
    this._userRepository,
  ) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _getUserProfileUseCase();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile({
    String? name,
    String? avatarKey,
  }) async {
    UserProfile? current = state.value;
    if (current == null) {
      try {
        current = await _getUserProfileUseCase();
      } catch (_) {
        current = null;
      }
    }
    if (current == null) return;

    final updated = current.copyWith(
      name: name ?? current.name,
      avatarKey: avatarKey ?? current.avatarKey,
    );

    try {
      await _updateUserProfileUseCase(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserProfile?> addQuestRewards({
    required int xp,
    required int coins,
    required String questId,
  }) async {
    try {
      final updated = await _userRepository.addXpAndCoins(
        xp: xp,
        coins: coins,
        completedQuestId: questId,
      );
      state = AsyncValue.data(updated);
      return updated;
    } catch (e) {
      return null;
    }
  }
}

final userProfileNotifierProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  final getUseCase = ref.watch(getUserProfileUseCaseProvider);
  final updateUseCase = ref.watch(updateUserProfileUseCaseProvider);
  final repo = ref.watch(userRepositoryProvider);
  return UserProfileNotifier(getUseCase, updateUseCase, repo);
});
