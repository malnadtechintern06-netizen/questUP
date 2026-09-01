import 'package:quest_up/features/auth/domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser> loginWithEmailPassword({
    required String email,
    required String password,
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
