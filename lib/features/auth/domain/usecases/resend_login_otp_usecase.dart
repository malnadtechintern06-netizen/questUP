import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class ResendLoginOtpUseCase {
  final AuthRepository _repository;

  const ResendLoginOtpUseCase(this._repository);

  Future<bool> call({
    required String email,
  }) async {
    return await _repository.resendLoginOtp(
      email: email,
    );
  }
}
