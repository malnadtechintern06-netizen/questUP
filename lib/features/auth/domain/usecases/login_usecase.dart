import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<AuthUser> call({
    required String email,
    required String password,
  }) async {
    return await _repository.loginWithEmailPassword(
      email: email,
      password: password,
    );
  }
}
