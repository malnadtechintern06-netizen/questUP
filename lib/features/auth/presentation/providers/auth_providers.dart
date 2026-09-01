import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:quest_up/features/auth/domain/usecases/get_auth_state_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/login_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/logout_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/register_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';

// Data Source Provider
final authRemoteDataSourceProvider = Provider<IAuthRemoteDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return AuthFirebaseDataSource(storage);
});

// Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource: dataSource);
});

// Use Cases Providers
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginUseCase(repo);
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return RegisterUseCase(repo);
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repo);
});

final sendPasswordResetUseCaseProvider = Provider<SendPasswordResetUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SendPasswordResetUseCase(repo);
});

final getAuthStateUseCaseProvider = Provider<GetAuthStateUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return GetAuthStateUseCase(repo);
});

// Auth Stream Provider
final authStateStreamProvider = StreamProvider<AuthUser?>((ref) {
  final getAuthState = ref.watch(getAuthStateUseCaseProvider);
  return getAuthState();
});

// State for Authentication State Notifier
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final SendPasswordResetUseCase sendPasswordResetUseCase;
  final GetAuthStateUseCase getAuthStateUseCase;
  final Ref ref;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthNotifier({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.sendPasswordResetUseCase,
    required this.getAuthStateUseCase,
    required this.ref,
  }) : super(const AuthState()) {
    checkInitialAuthState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = getAuthStateUseCase().listen((user) {
      if (user != null) {
        if (state.user?.id != user.id || state.status != AuthStatus.authenticated) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            errorMessage: null,
          );
        }
      }
    });
  }

  Future<AuthState> checkInitialAuthState() async {
    try {
      final user = await getAuthStateUseCase.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          errorMessage: null,
        );
      }
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
      );
    }
    return state;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await loginUseCase(
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );

      // Sync profile name
      ref.read(userProfileNotifierProvider.notifier).updateProfile(
            name: user.displayName,
          );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await registerUseCase(
        name: name,
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );

      // Set initial user profile alias
      ref.read(userProfileNotifierProvider.notifier).updateProfile(
            name: name,
          );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    await logoutUseCase();
    state = const AuthState(status: AuthStatus.unauthenticated, user: null);
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await sendPasswordResetUseCase(email);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final login = ref.watch(loginUseCaseProvider);
  final register = ref.watch(registerUseCaseProvider);
  final logout = ref.watch(logoutUseCaseProvider);
  final reset = ref.watch(sendPasswordResetUseCaseProvider);
  final getAuth = ref.watch(getAuthStateUseCaseProvider);

  return AuthNotifier(
    loginUseCase: login,
    registerUseCase: register,
    logoutUseCase: logout,
    sendPasswordResetUseCase: reset,
    getAuthStateUseCase: getAuth,
    ref: ref,
  );
});
