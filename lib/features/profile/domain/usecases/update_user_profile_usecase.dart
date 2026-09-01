import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

class UpdateUserProfileUseCase {
  final UserRepository _repository;

  const UpdateUserProfileUseCase(this._repository);

  Future<void> call(UserProfile profile) async {
    await _repository.saveUserProfile(profile);
  }
}
