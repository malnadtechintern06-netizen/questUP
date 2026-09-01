import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final IAuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<AuthUser?> get authStateChanges => remoteDataSource.authStateChanges;

  @override
  Future<AuthUser?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }

  @override
  Future<AuthUser> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.login(
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthUser> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.register(
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.logout();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await remoteDataSource.sendPasswordReset(email);
  }
}
