import '../entities/quest_completion.dart';
import '../repositories/verification_repository.dart';

class GetUserCompletionsUseCase {
  final VerificationRepository _repository;

  const GetUserCompletionsUseCase(this._repository);

  Future<List<QuestCompletion>> call(String userId) async {
    return await _repository.getCompletionsForUser(userId);
  }
}
