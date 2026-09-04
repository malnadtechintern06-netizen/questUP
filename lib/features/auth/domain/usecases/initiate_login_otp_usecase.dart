import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class InitiateLoginOtpUseCase {
  final AuthRepository _repository;

  const InitiateLoginOtpUseCase(this._repository);

  Future<bool> call({
    required String email,
    required String password,
  }) async {
    return await _repository.initiateLoginWithOtp(
      email: email,
      password: password,
    );
  }
}
