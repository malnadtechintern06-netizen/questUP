import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:quest_up/features/verification/data/datasources/verification_local_datasource.dart';

abstract class IDuplicateProofService {
  Future<String> computeFileHash(String filePath);
  String computeContentHash(String content);
  Future<bool> isDuplicateProof(String hash, {String? currentQuestId, String? currentUserId});
}

class DuplicateProofService implements IDuplicateProofService {
  final IVerificationLocalDataSource _dataSource;

  DuplicateProofService(this._dataSource);

  @override
  Future<String> computeFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        // Fallback for virtual paths / test strings
        return computeContentHash(filePath);
      }
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (_) {
      return computeContentHash(filePath);
    }
  }

  @override
  String computeContentHash(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  @override
  Future<bool> isDuplicateProof(String hash, {String? currentQuestId, String? currentUserId}) async {
    if (hash.isEmpty) return false;
    final allProofs = await _dataSource.getAllProofs();
    // Check if any previously verified proof shares this exact media hash
    return allProofs.any((proof) =>
        proof.mediaHash != null &&
        proof.mediaHash == hash &&
        proof.verificationStatus.name == 'verified');
  }
}
