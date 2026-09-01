import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class SendPasswordResetUseCase {
  final AuthRepository _repository;

  const SendPasswordResetUseCase(this._repository);

  Future<void> call(String email) async {
    await _repository.sendPasswordResetEmail(email);
  }
}
