import 'package:quest_up/features/auth/domain/entities/auth_user.dart';
import 'package:quest_up/features/auth/domain/repositories/auth_repository.dart';

class VerifyLoginOtpUseCase {
  final AuthRepository _repository;

  const VerifyLoginOtpUseCase(this._repository);

  Future<AuthUser> call({
    required String email,
    required String otp,
  }) async {
    return await _repository.verifyLoginOtp(
      email: email,
      otp: otp,
    );
  }
}
