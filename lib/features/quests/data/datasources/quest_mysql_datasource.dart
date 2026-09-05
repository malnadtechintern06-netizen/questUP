import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/config/mysql_config.dart';
import '../../../../core/services/mysql_database_service.dart';
import '../../../verification/domain/entities/quest_completion.dart';
import '../models/quest_model.dart';

abstract class IQuestMySqlDataSource {
  Future<List<QuestModel>> fetchQuestsFromMySql();
  Future<void> saveQuestToMySql(QuestModel quest);
  Future<bool> saveCompletionToMySql(QuestCompletion completion);
  Future<bool> isQuestCompletedByUserInMySql(String questId, String userId);
}

class QuestMySqlDataSource implements IQuestMySqlDataSource {
  final IMySqlDatabaseService _dbService;

  QuestMySqlDataSource([IMySqlDatabaseService? dbService])
      : _dbService = dbService ?? MySqlDatabaseService.instance;

  static String? _cachedTestCookie;
  Future<List<QuestModel>>? _inFlightFetch;

  Future<List<QuestModel>> _fetchFromRestApi() async {
    if (_inFlightFetch != null) {
      return await _inFlightFetch!;
    }
    final fetchFuture = _executeRestApiFetch();
    _inFlightFetch = fetchFuture;
    try {
      return await fetchFuture;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<List<QuestModel>> _executeRestApiFetch() async {
    for (final baseUrl in MySqlConfig.apiBaseUrls) {
      HttpClient? client;
      try {
        final uri = Uri.parse('$baseUrl/quests/list.php');
        debugPrint('[QUEST API] Requesting latest quests: $uri');

        client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 6000);
        client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

        // 1. First attempt (using cached __test cookie if available)
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        request.headers.set('Accept', 'application/json, text/html, */*');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('Pragma', 'no-cache');

        if (_cachedTestCookie != null && _cachedTestCookie!.isNotEmpty) {
          request.headers.set('Cookie', '__test=$_cachedTestCookie');
        }

        final response = await request.close().timeout(const Duration(milliseconds: 7000));
        debugPrint('[QUEST API] Response status: ${response.statusCode} from $baseUrl');

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();

          // Check if InfinityFree Anti-Bot challenge was returned
          if (responseBody.contains('slowAES')) {
            debugPrint('[QUEST API] InfinityFree security challenge detected. Resolving...');
            final cookieVal = _solveInfinityFreeChallenge(responseBody);

            if (cookieVal != null) {
              _cachedTestCookie = cookieVal;
              final locMatch = RegExp(r'location\.href="([^"]+)"').firstMatch(responseBody);
              final redirectUrl = locMatch?.group(1) ?? '$uri?i=1';

              // Step 2: Request redirect URL with solved cookie
              final req2 = await client.getUrl(Uri.parse(redirectUrl));
              req2.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
              req2.headers.set('Cookie', '__test=$cookieVal');
              req2.headers.set('Accept', 'application/json, text/plain, */*');

              final res2 = await req2.close().timeout(const Duration(milliseconds: 7000));
              final body2 = await res2.transform(utf8.decoder).join();

              if (!body2.contains('slowAES')) {
                final list = _parseQuestsFromJson(body2);
                if (list != null) {
                  debugPrint('[QUEST API] Received quest count: ${list.length}');
                  return list;
                }
              }

              // Step 3: Request original endpoint with established session
              final req3 = await client.getUrl(uri);
              req3.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
              req3.headers.set('Cookie', '__test=$cookieVal');
              req3.headers.set('Accept', 'application/json');

              final res3 = await req3.close().timeout(const Duration(milliseconds: 7000));
              final body3 = await res3.transform(utf8.decoder).join();

              final list = _parseQuestsFromJson(body3);
              if (list != null) {
                debugPrint('[QUEST API] Received quest count: ${list.length}');
                return list;
              }
            }
          } else {
            // Direct clean JSON response
            final list = _parseQuestsFromJson(responseBody);
            if (list != null) {
              debugPrint('[QUEST API] Received quest count: ${list.length}');
              return list;
            }
          }
        }
      } catch (e) {
        debugPrint('[QUEST API] Request failed on $baseUrl: $e');
      } finally {
        try {
          client?.close();
        } catch (_) {}
      }
    }
    return [];
  }

  List<QuestModel>? _parseQuestsFromJson(String rawJson) {
    try {
      final trimmed = rawJson.trim();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        return null;
      }
      final data = jsonDecode(trimmed);
      if (data is Map && data['success'] == true && data['quests'] is List) {
        final list = <QuestModel>[];
        for (final item in data['quests']) {
          try {
            final q = QuestModel.fromJson(Map<String, dynamic>.from(item));
            if (q.isActive) {
              list.add(q);
            }
          } catch (e) {
            debugPrint('[QUEST API] Quest item parse error: $e');
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('[QUEST API] JSON parse error: $e');
    }
    return null;
  }

  static String? _solveInfinityFreeChallenge(String html) {
    try {
      final aMatch = RegExp(r'toNumbers\("([0-9a-fA-F]+)"\)').allMatches(html).toList();
      if (aMatch.length < 3) return null;

      final a = _hexToNumbers(aMatch[0].group(1)!); // key
      final b = _hexToNumbers(aMatch[1].group(1)!); // iv
      final c = _hexToNumbers(aMatch[2].group(1)!); // ciphertext

      final decrypted = _slowAesDecryptCbc(c, a, b);
      return _numbersToHex(decrypted);
    } catch (_) {
      return null;
    }
  }

  static List<int> _hexToNumbers(String d) {
    final e = <int>[];
    for (int i = 0; i < d.length; i += 2) {
      e.add(int.parse(d.substring(i, i + 2), radix: 16));
    }
    return e;
  }

  static String _numbersToHex(List<int> d) {
    var e = '';
    for (int f = 0; f < d.length; f++) {
      e += (16 > d[f] ? '0' : '') + d[f].toRadixString(16);
    }
    return e.toLowerCase();
  }

  static const List<int> _aesSbox = [
    99,124,119,123,242,107,111,197,48,1,103,43,254,215,171,118,202,130,201,125,250,89,71,240,173,212,162,175,156,164,114,192,183,253,147,38,54,63,247,204,52,165,229,241,113,216,49,21,4,199,35,195,24,150,5,154,7,18,128,226,235,39,178,117,9,131,44,26,27,110,90,160,82,59,214,179,41,227,47,132,83,209,0,237,32,252,177,91,106,203,190,57,74,76,88,207,208,239,170,251,67,77,51,133,69,249,2,127,80,60,159,168,81,163,64,143,146,157,56,245,188,182,218,33,16,255,243,210,205,12,19,236,95,151,68,23,196,167,126,61,100,93,25,115,96,129,79,220,34,42,144,136,70,238,184,20,222,94,11,219,224,50,58,10,73,6,36,92,194,211,172,98,145,149,228,121,231,200,55,109,141,213,78,169,108,86,244,234,101,122,174,8,186,120,37,46,28,166,180,198,232,221,116,31,75,189,139,138,112,62,181,102,72,3,246,14,97,53,87,185,134,193,29,158,225,248,152,17,105,217,142,148,155,30,135,233,206,85,40,223,140,161,137,13,191,230,66,104,65,153,45,15,176,84,187,22
  ];

  static const List<int> _aesRsbox = [
    82,9,106,213,48,54,165,56,191,64,163,158,129,243,215,251,124,227,57,130,155,47,255,135,52,142,67,68,196,222,233,203,84,123,148,50,166,194,35,61,238,76,149,11,66,250,195,78,8,46,161,102,40,217,36,178,118,91,162,73,109,139,209,37,114,248,246,100,134,104,152,22,212,164,92,204,93,101,182,146,108,112,72,80,253,237,185,218,94,21,70,87,167,141,157,132,144,216,171,0,140,188,211,10,247,228,88,5,184,179,69,6,208,44,30,143,202,63,15,2,193,175,189,3,1,19,138,107,58,145,17,65,79,103,220,234,151,242,207,206,240,180,230,115,150,172,116,34,231,173,53,133,226,249,55,232,28,117,223,110,71,241,26,113,29,41,197,137,111,183,98,14,170,24,190,27,252,86,62,75,198,210,121,32,154,219,192,254,120,205,90,244,31,221,168,51,136,7,199,49,177,18,16,89,39,128,236,95,96,81,127,169,25,181,74,13,45,229,122,159,147,201,156,239,160,224,59,77,174,42,245,176,200,235,187,60,131,83,153,97,23,43,4,126,186,119,214,38,225,105,20,99,85,33,12,125
  ];

  static const List<int> _aesRcon = [
    141,1,2,4,8,16,32,64,128,27,54,108,216,171,77,154,47,94,188,99,198,151,53,106,212,179,125,250,239,197,145,57,114,228,211,189,97,194,159,37,74,148,51,102,204,131,29,58,116,232,203
  ];

  static List<int> _slowAesDecryptCbc(List<int> cipher, List<int> key, List<int> iv) {
    final block = _slowAesDecryptBlock(cipher.sublist(0, 16), key, key.length);
    final u = List<int>.filled(16, 0);
    for (int i = 0; i < 16; i++) {
      u[i] = iv[i] ^ block[i];
    }
    return u;
  }

  static List<int> _slowAesDecryptBlock(List<int> i, List<int> t, int r) {
    final n = List<int>.filled(16, 0);
    for (int e = 0; e < 4; e++) {
      for (int a = 0; a < 4; a++) {
        n[e + 4 * a] = i[4 * e + a];
      }
    }
    final expanded = _slowAesExpandKey(t, r);
    final decrypted = _slowAesInvMain(n, expanded, 10);
    final o = List<int>.filled(16, 0);
    for (int h = 0; h < 4; h++) {
      for (int u = 0; u < 4; u++) {
        o[4 * h + u] = decrypted[h + 4 * u];
      }
    }
    return o;
  }

  static List<int> _slowAesExpandKey(List<int> i, int t) {
    final r = 16 * (10 + 1);
    int o = 0;
    int n = 1;
    final e = List<int>.filled(r, 0);
    for (int h = 0; h < t; h++) {
      e[h] = i[h];
    }
    o += t;
    while (o < r) {
      var s = [e[o - 4], e[o - 3], e[o - 2], e[o - 1]];
      if (o % t == 0) {
        final rot = [s[1], s[2], s[3], s[0]];
        for (int x = 0; x < 4; x++) {
          rot[x] = _aesSbox[rot[x]];
        }
        rot[0] ^= _aesRcon[n++];
        s = rot;
      }
      for (int l = 0; l < 4; l++) {
        e[o] = e[o - t] ^ s[l];
        o++;
      }
    }
    return e;
  }

  static List<int> _slowAesAddRoundKey(List<int> i, List<int> t) {
    final res = List<int>.filled(16, 0);
    for (int r = 0; r < 16; r++) {
      res[r] = i[r] ^ t[r];
    }
    return res;
  }

  static List<int> _slowAesCreateRoundKey(List<int> i, int t) {
    final r = List<int>.filled(16, 0);
    for (int o = 0; o < 4; o++) {
      for (int n = 0; n < 4; n++) {
        r[4 * n + o] = i[t + 4 * o + n];
      }
    }
    return r;
  }

  static List<int> _slowAesSubBytes(List<int> i, bool isInv) {
    final box = isInv ? _aesRsbox : _aesSbox;
    final res = List<int>.filled(16, 0);
    for (int r = 0; r < 16; r++) {
      res[r] = box[i[r]];
    }
    return res;
  }

  static List<int> _slowAesShiftRows(List<int> i, bool isInv) {
    final res = List<int>.from(i);
    for (int r = 0; r < 4; r++) {
      _slowAesShiftRow(res, 4 * r, r, isInv);
    }
    return res;
  }

  static void _slowAesShiftRow(List<int> i, int t, int r, bool isInv) {
    for (int n = 0; n < r; n++) {
      if (isInv) {
        final s = i[t + 3];
        for (int e = 3; 0 < e; e--) {
          i[t + e] = i[t + e - 1];
        }
        i[t] = s;
      } else {
        final s = i[t];
        for (int e = 0; e < 3; e++) {
          i[t + e] = i[t + e + 1];
        }
        i[t + 3] = s;
      }
    }
  }

  static int _slowAesGaloisMul(int i, int t) {
    int r = 0;
    for (int o = 0; o < 8; o++) {
      if ((1 & t) == 1) r ^= i;
      if (256 < r) r ^= 256;
      final n = 128 & i;
      i <<= 1;
      if (256 < i) i ^= 256;
      if (128 == n) i ^= 27;
      if (256 < i) i ^= 256;
      t >>= 1;
      if (256 < t) t ^= 256;
    }
    return r;
  }

  static List<int> _slowAesMixColumns(List<int> i, bool isInv) {
    final res = List<int>.from(i);
    for (int o = 0; o < 4; o++) {
      var r = [res[o], res[4 + o], res[8 + o], res[12 + o]];
      r = _slowAesMixColumn(r, isInv);
      for (int s = 0; s < 4; s++) {
        res[4 * s + o] = r[s];
      }
    }
    return res;
  }

  static List<int> _slowAesMixColumn(List<int> i, bool isInv) {
    final r = isInv ? [14, 9, 13, 11] : [2, 1, 1, 3];
    final o = List<int>.from(i);
    final res = List<int>.filled(4, 0);
    res[0] = _slowAesGaloisMul(o[0], r[0]) ^ _slowAesGaloisMul(o[3], r[1]) ^ _slowAesGaloisMul(o[2], r[2]) ^ _slowAesGaloisMul(o[1], r[3]);
    res[1] = _slowAesGaloisMul(o[1], r[0]) ^ _slowAesGaloisMul(o[0], r[1]) ^ _slowAesGaloisMul(o[3], r[2]) ^ _slowAesGaloisMul(o[2], r[3]);
    res[2] = _slowAesGaloisMul(o[2], r[0]) ^ _slowAesGaloisMul(o[1], r[1]) ^ _slowAesGaloisMul(o[0], r[2]) ^ _slowAesGaloisMul(o[3], r[3]);
    res[3] = _slowAesGaloisMul(o[3], r[0]) ^ _slowAesGaloisMul(o[2], r[1]) ^ _slowAesGaloisMul(o[1], r[2]) ^ _slowAesGaloisMul(o[0], r[3]);
    return res;
  }

  static List<int> _slowAesInvRound(List<int> i, List<int> t) {
    var state = _slowAesShiftRows(i, true);
    state = _slowAesSubBytes(state, true);
    state = _slowAesAddRoundKey(state, t);
    state = _slowAesMixColumns(state, true);
    return state;
  }

  static List<int> _slowAesInvMain(List<int> i, List<int> t, int r) {
    var state = _slowAesAddRoundKey(i, _slowAesCreateRoundKey(t, 16 * r));
    for (int o = r - 1; 0 < o; o--) {
      state = _slowAesInvRound(state, _slowAesCreateRoundKey(t, 16 * o));
    }
    state = _slowAesShiftRows(state, true);
    state = _slowAesSubBytes(state, true);
    state = _slowAesAddRoundKey(state, _slowAesCreateRoundKey(t, 0));
    return state;
  }

  @override
  Future<List<QuestModel>> fetchQuestsFromMySql() async {
    // 1. Try Cloud REST API first (works seamlessly on InfinityFree & mobile devices)
    final restQuests = await _fetchFromRestApi();
    if (restQuests.isNotEmpty) {
      return restQuests;
    }

    // 2. Fallback to direct MySQL TCP (for local / LAN setups)
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return [];

    try {
      final result = await _dbService.execute(
        'SELECT * FROM quests WHERE is_active = 1 ORDER BY created_at DESC',
      );

      if (result == null || result.rows.isEmpty) {
        return [];
      }

      final quests = <QuestModel>[];
      for (final row in result.rows) {
        try {
          final map = row.assoc();
          final questMap = <String, dynamic>{
            'id': map['id'] ?? const Uuid().v4(),
            'title': map['title'] ?? 'Landmark Quest',
            'description': map['description'] ?? 'Discover this location.',
            'category': map['category'] ?? 'location',
            'verificationType': map['verification_type'] ?? 'locationGps',
            'latitude': double.tryParse(map['latitude'] ?? '') ?? 0.0,
            'longitude': double.tryParse(map['longitude'] ?? '') ?? 0.0,
            'radiusMeters': double.tryParse(map['radius_meters'] ?? '') ?? 150.0,
            'xpReward': int.tryParse(map['xp_reward'] ?? '') ?? 100,
            'coinReward': int.tryParse(map['coins_reward'] ?? '') ?? 50,
            'locationName': map['location_name'] ?? 'Waypoint',
            'difficulty': map['difficulty'] ?? 'medium',
            'isActive': (map['is_active'] == '1' || map['is_active'] == 'true'),
          };

          if (map['image_asset_path'] != null && map['image_asset_path']!.isNotEmpty) {
            questMap['photoUrl'] = map['image_asset_path'];
            questMap['imageUrl'] = map['image_asset_path'];
          }

          final quest = QuestModel.fromJson(questMap);
          quests.add(quest);
        } catch (e) {
          debugPrint('[MySQL] Quest row parse error: $e');
        }
      }
      debugPrint('[MySQL] Fetched ${quests.length} active quests from MySQL');
      return quests;
    } catch (e) {
      debugPrint('[MySQL] fetchQuests error: $e');
      return [];
    }
  }

  @override
  Future<void> saveQuestToMySql(QuestModel quest) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return;

    try {
      await _dbService.execute(
        '''
        INSERT INTO quests (id, title, description, category, verification_type, latitude, longitude, radius_meters, xp_reward, coins_reward, location_name, place_type, image_asset_path, difficulty, is_active, created_at)
        VALUES (:id, :title, :description, :category, :verification_type, :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward, :location_name, :place_type, :image_asset_path, :difficulty, 1, NOW())
        ON DUPLICATE KEY UPDATE
          title = VALUES(title),
          description = VALUES(description),
          xp_reward = VALUES(xp_reward),
          coins_reward = VALUES(coins_reward)
        ''',
        {
          'id': quest.id,
          'title': quest.title,
          'description': quest.description,
          'category': quest.category.name,
          'verification_type': quest.verificationType.name,
          'latitude': quest.latitude.toString(),
          'longitude': quest.longitude.toString(),
          'radius_meters': quest.radiusMeters.toString(),
          'xp_reward': quest.xpReward.toString(),
          'coins_reward': quest.coinReward.toString(),
          'location_name': quest.locationName,
          'place_type': quest.placeCategory ?? 'landmark',
          'image_asset_path': quest.imageUrl ?? quest.photoUrl ?? 'assets/images/hero_poster.jpg',
          'difficulty': quest.difficulty.name,
        },
      );
      debugPrint('[MySQL] MYSQL QUEST INSERT/UPDATE SUCCESS: ${quest.title} (${quest.id})');
    } catch (e) {
      debugPrint('[MySQL] MYSQL QUEST INSERT FAILED: $e');
    }
  }

  @override
  Future<bool> isQuestCompletedByUserInMySql(String questId, String userId) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return false;

    try {
      final result = await _dbService.execute(
        'SELECT id FROM quest_completions WHERE quest_id = :quest_id AND user_id = :user_id LIMIT 1',
        {
          'quest_id': questId,
          'user_id': userId,
        },
      );
      return result != null && result.rows.isNotEmpty;
    } catch (e) {
      debugPrint('[MySQL] Check duplicate completion error: $e');
      return false;
    }
  }

  @override
  Future<bool> saveCompletionToMySql(QuestCompletion completion) async {
    final isDbReady = await _dbService.connect();
    if (!isDbReady) return false;

    try {
      // 1. Duplicate check
      final alreadyExists = await isQuestCompletedByUserInMySql(completion.questId, completion.userId);
      if (alreadyExists) {
        debugPrint('[MySQL] Duplicate quest completion ignored: questId=${completion.questId}, userId=${completion.userId}');
        return true;
      }

      // 2. Insert into quest_completions
      final proofJson = completion.photoProofPath.isNotEmpty
          ? '{"proof":"${completion.photoProofPath}","lat":${completion.userLatitude},"lng":${completion.userLongitude}}'
          : null;

      final res = await _dbService.execute(
        '''
        INSERT INTO quest_completions (
          id, quest_id, user_id, verification_type, proof_data,
          xp_earned, coins_earned, completed_at, status
        ) VALUES (
          :id, :quest_id, :user_id, :verification_type, :proof_data,
          :xp_earned, :coins_earned, :completed_at, 'verified'
        )
        ''',
        {
          'id': completion.id.isNotEmpty ? completion.id : const Uuid().v4(),
          'quest_id': completion.questId,
          'user_id': completion.userId,
          'verification_type': 'locationGps',
          'proof_data': proofJson,
          'xp_earned': completion.xpEarned.toString(),
          'coins_earned': completion.coinsEarned.toString(),
          'completed_at': completion.completedAt.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
        },
      );

      if (res != null) {
        debugPrint('[MySQL] MYSQL QUEST COMPLETION INSERT SUCCESS: questId=${completion.questId}, userId=${completion.userId}, XP=+${completion.xpEarned}, Coins=+${completion.coinsEarned}');
        return true;
      } else {
        debugPrint('[MySQL] MYSQL QUEST COMPLETION INSERT FAILED: Query returned null');
        return false;
      }
    } catch (e) {
      debugPrint('[MySQL] MYSQL QUEST COMPLETION INSERT FAILED: $e');
      return false;
    }
  }
}
