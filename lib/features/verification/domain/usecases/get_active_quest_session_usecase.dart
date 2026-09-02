import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';

class GetActiveQuestSessionUseCase {
  final VerificationRepository repository;

  GetActiveQuestSessionUseCase(this.repository);

  Future<QuestSession?> call({
    required String questId,
    required String userId,
  }) {
    return repository.getActiveQuestSession(
      questId: questId,
      userId: userId,
    );
  }
}
