import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/quest_model.dart';

abstract class IQuestFirestoreDataSource {
  Future<List<QuestModel>> fetchQuestsFromFirestore();
  Future<void> saveQuestToFirestore(QuestModel quest);
  Future<void> markCompletedInFirestore(String questId, String userId);
}

class QuestFirestoreDataSource implements IQuestFirestoreDataSource {
  static const String collectionName = 'quests';

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Future<List<QuestModel>> fetchQuestsFromFirestore() async {
    if (!_isFirebaseReady) return [];

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('active', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        // Also check with field name 'isActive'
        final altSnapshot = await _firestore
            .collection(collectionName)
            .where('isActive', isEqualTo: true)
            .get();
        if (altSnapshot.docs.isNotEmpty) {
          return altSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return QuestModel.fromJson(data);
          }).toList();
        }
        return [];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return QuestModel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Firestore fetchQuests error: $e');
      return [];
    }
  }

  @override
  Future<void> saveQuestToFirestore(QuestModel quest) async {
    if (!_isFirebaseReady) return;

    try {
      await _firestore
          .collection(collectionName)
          .doc(quest.id)
          .set(quest.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveQuest error: $e');
    }
  }

  @override
  Future<void> markCompletedInFirestore(String questId, String userId) async {
    if (!_isFirebaseReady) return;

    try {
      await _firestore.collection('completions').add({
        'questId': questId,
        'userId': userId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore markCompleted error: $e');
    }
  }
}
