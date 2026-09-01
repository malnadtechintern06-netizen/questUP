import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

class GetUserProfileUseCase {
  final UserRepository _repository;

  const GetUserProfileUseCase(this._repository);

  Future<UserProfile> call() async {
    return await _repository.getUserProfile();
  }
}
