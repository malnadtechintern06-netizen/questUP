import '../../../../app/config/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../domain/entities/quest_proof.dart';
import '../../domain/entities/quest_session.dart';
import '../models/quest_completion_model.dart';

abstract class IVerificationLocalDataSource {
  Future<List<QuestCompletionModel>> getCompletions([String? userId]);
  Future<void> saveCompletion(QuestCompletionModel completion);

  // Quest Sessions
  Future<void> saveQuestSession(QuestSession session);
  Future<QuestSession?> getQuestSession(String sessionId);
  Future<QuestSession?> getActiveSessionForQuest(String questId, String userId);
  Future<List<QuestSession>> getAllSessions([String? userId]);
  Future<void> updateQuestSession(QuestSession session);

  // Quest Proofs
  Future<void> saveProof(QuestProof proof);
  Future<List<QuestProof>> getAllProofs([String? userId]);
  Future<List<QuestProof>> getProofsForQuest(String questId, [String? userId]);
}

class VerificationLocalDataSource implements IVerificationLocalDataSource {
  final ILocalStorageService _storage;

  VerificationLocalDataSource(this._storage);

  Future<String?> _getActiveUserId() async {
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      if (authSession != null && authSession is Map<String, dynamic>) {
        return authSession['id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<QuestCompletionModel>> getCompletions([String? userId]) async {
    final activeUserId = userId ?? await _getActiveUserId();
    final jsonList = await _storage.getJson(AppConstants.keyCompletions);
    if (jsonList != null && jsonList is List) {
      final all = jsonList
          .map((item) => QuestCompletionModel.fromJson(item as Map<String, dynamic>))
          .toList();
      if (activeUserId != null && activeUserId.isNotEmpty) {
        return all.where((c) => c.userId == activeUserId).toList();
      }
      return all;
    }
    return [];
  }

  @override
  Future<void> saveCompletion(QuestCompletionModel completion) async {
    final jsonList = await _storage.getJson(AppConstants.keyCompletions);
    final list = (jsonList != null && jsonList is List)
        ? jsonList
            .map((item) => QuestCompletionModel.fromJson(item as Map<String, dynamic>))
            .toList()
        : <QuestCompletionModel>[];

    list.add(completion);
    await _storage.saveJson(AppConstants.keyCompletions, list.map((c) => c.toJson()).toList());
  }

  @override
  Future<void> saveQuestSession(QuestSession session) async {
    final jsonList = await _storage.getJson(AppConstants.keyQuestSessions);
    final list = (jsonList != null && jsonList is List)
        ? jsonList
            .map((item) => QuestSession.fromJson(item as Map<String, dynamic>))
            .toList()
        : <QuestSession>[];

    final index = list.indexWhere((s) => s.sessionId == session.sessionId);
    if (index >= 0) {
      list[index] = session;
    } else {
      list.add(session);
    }
    await _storage.saveJson(AppConstants.keyQuestSessions, list.map((s) => s.toJson()).toList());
  }

  @override
  Future<QuestSession?> getQuestSession(String sessionId) async {
    final list = await getAllSessions();
    return list.where((s) => s.sessionId == sessionId).firstOrNull;
  }

  @override
  Future<QuestSession?> getActiveSessionForQuest(String questId, String userId) async {
    final list = await getAllSessions(userId);
    return list
        .where((s) => s.questId == questId && s.userId == userId && s.isActive)
        .firstOrNull;
  }

  @override
  Future<List<QuestSession>> getAllSessions([String? userId]) async {
    final activeUserId = userId ?? await _getActiveUserId();
    final jsonList = await _storage.getJson(AppConstants.keyQuestSessions);
    if (jsonList != null && jsonList is List) {
      final all = jsonList
          .map((item) => QuestSession.fromJson(item as Map<String, dynamic>))
          .toList();
      if (activeUserId != null && activeUserId.isNotEmpty) {
        return all.where((s) => s.userId == activeUserId).toList();
      }
      return all;
    }
    return [];
  }

  @override
  Future<void> updateQuestSession(QuestSession session) async {
    await saveQuestSession(session);
  }

  @override
  Future<void> saveProof(QuestProof proof) async {
    final jsonList = await _storage.getJson(AppConstants.keyQuestProofs);
    final list = (jsonList != null && jsonList is List)
        ? jsonList
            .map((item) => QuestProof.fromJson(item as Map<String, dynamic>))
            .toList()
        : <QuestProof>[];

    final index = list.indexWhere((p) => p.proofId == proof.proofId);
    if (index >= 0) {
      list[index] = proof;
    } else {
      list.add(proof);
    }
    await _storage.saveJson(AppConstants.keyQuestProofs, list.map((p) => p.toJson()).toList());
  }

  @override
  Future<List<QuestProof>> getAllProofs([String? userId]) async {
    final activeUserId = userId ?? await _getActiveUserId();
    final jsonList = await _storage.getJson(AppConstants.keyQuestProofs);
    if (jsonList != null && jsonList is List) {
      final all = jsonList
          .map((item) => QuestProof.fromJson(item as Map<String, dynamic>))
          .toList();
      if (activeUserId != null && activeUserId.isNotEmpty) {
        return all.where((p) => p.userId == activeUserId).toList();
      }
      return all;
    }
    return [];
  }

  @override
  Future<List<QuestProof>> getProofsForQuest(String questId, [String? userId]) async {
    final list = await getAllProofs(userId);
    return list.where((p) => p.questId == questId).toList();
  }
}
