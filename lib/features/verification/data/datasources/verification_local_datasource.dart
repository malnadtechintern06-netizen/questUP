import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../domain/entities/quest_proof.dart';
import '../../domain/entities/quest_session.dart';
import '../models/quest_completion_model.dart';

abstract class IVerificationLocalDataSource {
  Future<List<QuestCompletionModel>> getCompletions();
  Future<void> saveCompletion(QuestCompletionModel completion);

  // Quest Sessions
  Future<void> saveQuestSession(QuestSession session);
  Future<QuestSession?> getQuestSession(String sessionId);
  Future<QuestSession?> getActiveSessionForQuest(String questId, String userId);
  Future<List<QuestSession>> getAllSessions();
  Future<void> updateQuestSession(QuestSession session);

  // Quest Proofs
  Future<void> saveProof(QuestProof proof);
  Future<List<QuestProof>> getAllProofs();
  Future<List<QuestProof>> getProofsForQuest(String questId);
}

class VerificationLocalDataSource implements IVerificationLocalDataSource {
  final ILocalStorageService _storage;

  VerificationLocalDataSource(this._storage);

  @override
  Future<List<QuestCompletionModel>> getCompletions() async {
    final jsonList = await _storage.getJson(AppConstants.keyCompletions);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => QuestCompletionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveCompletion(QuestCompletionModel completion) async {
    final list = await getCompletions();
    list.add(completion);
    final jsonList = list.map((c) => c.toJson()).toList();
    await _storage.saveJson(AppConstants.keyCompletions, jsonList);
  }

  @override
  Future<void> saveQuestSession(QuestSession session) async {
    final list = await getAllSessions();
    final index = list.indexWhere((s) => s.sessionId == session.sessionId);
    if (index >= 0) {
      list[index] = session;
    } else {
      list.add(session);
    }
    final jsonList = list.map((s) => s.toJson()).toList();
    await _storage.saveJson(AppConstants.keyQuestSessions, jsonList);
  }

  @override
  Future<QuestSession?> getQuestSession(String sessionId) async {
    final list = await getAllSessions();
    return list.where((s) => s.sessionId == sessionId).firstOrNull;
  }

  @override
  Future<QuestSession?> getActiveSessionForQuest(String questId, String userId) async {
    final list = await getAllSessions();
    return list
        .where((s) => s.questId == questId && s.userId == userId && s.isActive)
        .firstOrNull;
  }

  @override
  Future<List<QuestSession>> getAllSessions() async {
    final jsonList = await _storage.getJson(AppConstants.keyQuestSessions);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => QuestSession.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<void> updateQuestSession(QuestSession session) async {
    await saveQuestSession(session);
  }

  @override
  Future<void> saveProof(QuestProof proof) async {
    final list = await getAllProofs();
    final index = list.indexWhere((p) => p.proofId == proof.proofId);
    if (index >= 0) {
      list[index] = proof;
    } else {
      list.add(proof);
    }
    final jsonList = list.map((p) => p.toJson()).toList();
    await _storage.saveJson(AppConstants.keyQuestProofs, jsonList);
  }

  @override
  Future<List<QuestProof>> getAllProofs() async {
    final jsonList = await _storage.getJson(AppConstants.keyQuestProofs);
    if (jsonList != null && jsonList is List) {
      return jsonList
          .map((item) => QuestProof.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<List<QuestProof>> getProofsForQuest(String questId) async {
    final list = await getAllProofs();
    return list.where((p) => p.questId == questId).toList();
  }
}
