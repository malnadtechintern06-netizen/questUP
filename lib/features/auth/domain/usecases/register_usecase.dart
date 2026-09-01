import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  Future<AuthUser> call({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _repository.registerWithEmailPassword(
      name: name,
      email: email,
      password: password,
    );
  }
}
