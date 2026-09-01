import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class GetAuthStateUseCase {
  final AuthRepository _repository;

  const GetAuthStateUseCase(this._repository);

  Stream<AuthUser?> call() {
    return _repository.authStateChanges;
  }

  Future<AuthUser?> getCurrentUser() {
    return _repository.getCurrentUser();
  }
}
