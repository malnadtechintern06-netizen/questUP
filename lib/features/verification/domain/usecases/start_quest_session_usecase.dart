import 'package:quest_up/features/verification/domain/entities/quest_session.dart';
import 'package:quest_up/features/verification/domain/repositories/verification_repository.dart';

class StartQuestSessionUseCase {
  final VerificationRepository repository;

  StartQuestSessionUseCase(this.repository);

  Future<QuestSession> call({
    required String questId,
    required String userId,
    double? startingLat,
    double? startingLon,
    String? requiredProofType,
  }) {
    return repository.startQuestSession(
      questId: questId,
      userId: userId,
      startingLat: startingLat,
      startingLon: startingLon,
      requiredProofType: requiredProofType,
    );
  }
}
