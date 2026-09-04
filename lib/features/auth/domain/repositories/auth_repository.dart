import 'package:quest_up/features/auth/domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<bool> initiateLoginWithOtp({
    required String email,
    required String password,
  });

  Future<AuthUser> verifyLoginOtp({
    required String email,
    required String otp,
  });

  Future<bool> resendLoginOtp({
    required String email,
  });

  Future<AuthUser> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<void> sendPasswordResetEmail(String email);

  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser?> getCurrentUser();
}
