import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:quest_up/features/auth/domain/usecases/get_auth_state_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/initiate_login_otp_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/login_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/logout_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/register_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/resend_login_otp_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/verify_login_otp_usecase.dart';
import 'package:quest_up/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:quest_up/features/calendar/presentation/providers/quest_calendar_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';

// Data Source Provider
final authRemoteDataSourceProvider = Provider<IAuthRemoteDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return AuthMySqlDataSource(storage);
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

final initiateLoginOtpUseCaseProvider = Provider<InitiateLoginOtpUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return InitiateLoginOtpUseCase(repo);
});

final verifyLoginOtpUseCaseProvider = Provider<VerifyLoginOtpUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return VerifyLoginOtpUseCase(repo);
});

final resendLoginOtpUseCaseProvider = Provider<ResendLoginOtpUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ResendLoginOtpUseCase(repo);
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
  otpSent,
  loading,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;
  final String? pendingOtpEmail;
  final bool isResendingOtp;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.pendingOtpEmail,
    this.isResendingOtp = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isOtpSent => status == AuthStatus.otpSent;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? errorMessage,
    String? pendingOtpEmail,
    bool? isResendingOtp,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      pendingOtpEmail: pendingOtpEmail ?? this.pendingOtpEmail,
      isResendingOtp: isResendingOtp ?? this.isResendingOtp,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final InitiateLoginOtpUseCase initiateLoginOtpUseCase;
  final VerifyLoginOtpUseCase verifyLoginOtpUseCase;
  final ResendLoginOtpUseCase resendLoginOtpUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final SendPasswordResetUseCase sendPasswordResetUseCase;
  final GetAuthStateUseCase getAuthStateUseCase;
  final Ref ref;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthNotifier({
    required this.loginUseCase,
    required this.initiateLoginOtpUseCase,
    required this.verifyLoginOtpUseCase,
    required this.resendLoginOtpUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.sendPasswordResetUseCase,
    required this.getAuthStateUseCase,
    required this.ref,
  }) : super(const AuthState()) {
    checkInitialAuthState();
    _listenToAuthChanges();
  }

  Future<void> _hydrateUserDataInBackground(AuthUser user) async {
    final swProfile = Stopwatch()..start();
    try {
      await ref.read(userProfileNotifierProvider.notifier).updateProfile(
            id: user.id,
            name: user.displayName,
            email: user.email,
          );
      debugPrint('[TIMING] PROFILE LOAD (${swProfile.elapsedMilliseconds}ms): Profile synced for ${user.id}');
    } catch (_) {}

    // Concurrently fetch non-blocking data in background
    unawaited(Future.wait([
      _loadQuestsWithTiming(),
      _loadHistoryWithTiming(user.id),
      _loadBadgesWithTiming(user.id),
      _loadNotificationsWithTiming(),
    ]).catchError((_) => <dynamic>[]));
  }

  Future<void> _loadQuestsWithTiming() async {
    final sw = Stopwatch()..start();
    try {
      await ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
      debugPrint('[TIMING] QUEST LOAD (${sw.elapsedMilliseconds}ms)');
    } catch (_) {}
  }

  Future<void> _loadHistoryWithTiming(String userId) async {
    final sw = Stopwatch()..start();
    try {
      await ref.read(questCalendarNotifierProvider.notifier).refresh();
      debugPrint('[TIMING] HISTORY LOAD (${sw.elapsedMilliseconds}ms)');
    } catch (_) {}
  }

  Future<void> _loadBadgesWithTiming(String userId) async {
    final sw = Stopwatch()..start();
    try {
      await ref.read(achievementsNotifierProvider.notifier).loadAchievements();
      debugPrint('[TIMING] BADGES LOAD (${sw.elapsedMilliseconds}ms)');
    } catch (_) {}
  }

  Future<void> _loadNotificationsWithTiming() async {
    final sw = Stopwatch()..start();
    try {
      debugPrint('[TIMING] NOTIFICATIONS LOAD (${sw.elapsedMilliseconds}ms)');
    } catch (_) {}
  }

  void _listenToAuthChanges() {
    _authSubscription = getAuthStateUseCase().listen((user) async {
      if (user != null) {
        if (state.user?.id != user.id || state.status != AuthStatus.authenticated) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            errorMessage: null,
            pendingOtpEmail: null,
          );
          _hydrateUserDataInBackground(user);
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
        _hydrateUserDataInBackground(user);
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

  Future<bool> initiateLoginWithOtp({
    required String email,
    required String password,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('[TIMING] LOGIN API START: Initiating OTP for $email');
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      pendingOtpEmail: email.trim().toLowerCase(),
    );
    try {
      final success = await initiateLoginOtpUseCase(
        email: email,
        password: password,
      );
      debugPrint('[TIMING] LOGIN API END (${sw.elapsedMilliseconds}ms): OTP generation result=$success');
      if (success) {
        state = state.copyWith(
          status: AuthStatus.otpSent,
          pendingOtpEmail: email.trim().toLowerCase(),
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Failed to generate verification code. Please try again.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[TIMING] LOGIN API ERROR (${sw.elapsedMilliseconds}ms): $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('[TIMING] LOGIN API START: Verifying OTP for $email');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await verifyLoginOtpUseCase(
        email: email,
        otp: otp,
      );
      debugPrint('[TIMING] LOGIN API END (${sw.elapsedMilliseconds}ms): OTP verified for ${user.id}');
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        pendingOtpEmail: null,
        errorMessage: null,
      );

      // Hydrate user profile and secondary data in background without blocking UI navigation
      _hydrateUserDataInBackground(user);
      return true;
    } catch (e) {
      debugPrint('[TIMING] LOGIN API ERROR (${sw.elapsedMilliseconds}ms): $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  Future<bool> resendOtp({required String email}) async {
    state = state.copyWith(isResendingOtp: true, errorMessage: null);
    try {
      final success = await resendLoginOtpUseCase(email: email);
      state = state.copyWith(
        isResendingOtp: false,
        pendingOtpEmail: email.trim().toLowerCase(),
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isResendingOtp: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('[TIMING] LOGIN API START: Direct login for $email');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await loginUseCase(
        email: email,
        password: password,
      );
      debugPrint('[TIMING] LOGIN API END (${sw.elapsedMilliseconds}ms): Direct login verified for ${user.id}');
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );

      // Hydrate user profile and secondary data in background without blocking UI navigation
      _hydrateUserDataInBackground(user);
      return true;
    } catch (e) {
      debugPrint('[TIMING] LOGIN API ERROR (${sw.elapsedMilliseconds}ms): $e');
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
    final sw = Stopwatch()..start();
    debugPrint('[TIMING] LOGIN API START: Registering $email');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await registerUseCase(
        name: name,
        email: email,
        password: password,
      );
      debugPrint('[TIMING] LOGIN API END (${sw.elapsedMilliseconds}ms): Registered user ${user.id}');
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );

      // Hydrate user profile and secondary data in background without blocking UI navigation
      _hydrateUserDataInBackground(user);
      return true;
    } catch (e) {
      debugPrint('[TIMING] LOGIN API ERROR (${sw.elapsedMilliseconds}ms): $e');
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
    await ref.read(userProfileNotifierProvider.notifier).loadProfile();
    await ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
    await ref.read(achievementsNotifierProvider.notifier).loadAchievements();
    await ref.read(questCalendarNotifierProvider.notifier).refresh();
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

  void setPendingOtpEmail(String? email) {
    state = state.copyWith(pendingOtpEmail: email);
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
  final initiateOtp = ref.watch(initiateLoginOtpUseCaseProvider);
  final verifyOtp = ref.watch(verifyLoginOtpUseCaseProvider);
  final resendOtp = ref.watch(resendLoginOtpUseCaseProvider);
  final register = ref.watch(registerUseCaseProvider);
  final logout = ref.watch(logoutUseCaseProvider);
  final reset = ref.watch(sendPasswordResetUseCaseProvider);
  final getAuth = ref.watch(getAuthStateUseCaseProvider);

  return AuthNotifier(
    loginUseCase: login,
    initiateLoginOtpUseCase: initiateOtp,
    verifyLoginOtpUseCase: verifyOtp,
    resendLoginOtpUseCase: resendOtp,
    registerUseCase: register,
    logoutUseCase: logout,
    sendPasswordResetUseCase: reset,
    getAuthStateUseCase: getAuth,
    ref: ref,
  );
});
