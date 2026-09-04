import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/friends/data/models/friend_profile_model.dart';
import 'package:quest_up/features/friends/data/models/friend_request_model.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';

abstract class IFriendsLocalDataSource {
  Future<List<FriendProfileModel>> getFriends();
  Future<void> saveFriends(List<FriendProfileModel> friends);

  Future<List<FriendRequestModel>> getFriendRequests();
  Future<void> saveFriendRequests(List<FriendRequestModel> requests);

  Future<List<FriendProfileModel>> getPlayerRegistry();
  Future<void> savePlayerRegistry(List<FriendProfileModel> players);

  String computePlayerTag(String userId, [String? email]);
}

class FriendsLocalDataSource implements IFriendsLocalDataSource {
  final ILocalStorageService _storage;

  FriendsLocalDataSource(this._storage);

  @override
  String computePlayerTag(String userId, [String? email]) {
    // Generate a clean memorable player tag like QST-4821
    final source = email != null && email.isNotEmpty ? email : userId;
    final bytes = utf8.encode(source);
    final hash = sha256.convert(bytes).toString();
    final numberPart = int.parse(hash.substring(0, 4), radix: 16) % 9000 + 1000;
    return 'QST-$numberPart';
  }

  Future<String> _getActiveUserId() async {
    try {
      final authSession = await _storage.getJson(AppConstants.keyAuthSession);
      if (authSession != null && authSession is Map<String, dynamic>) {
        return authSession['id']?.toString() ?? 'guest_player';
      }
    } catch (_) {}
    return 'guest_player';
  }

  @override
  Future<List<FriendProfileModel>> getFriends() async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friends_${userId}_v1';
    final raw = await _storage.getJson(userSpecificKey);
    if (raw is List) {
      return raw
          .map((item) => FriendProfileModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    // Initial seeded friend: Aria Silverleaf
    final initialFriends = [
      _getAriaSilverleafProfile(),
    ];
    await saveFriends(initialFriends);
    return initialFriends;
  }

  @override
  Future<void> saveFriends(List<FriendProfileModel> friends) async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friends_${userId}_v1';
    final list = friends.map((f) => f.toJson()).toList();
    await _storage.saveJson(userSpecificKey, list);
    await _storage.saveJson(AppConstants.keyFriends, list);
  }

  @override
  Future<List<FriendRequestModel>> getFriendRequests() async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friend_requests_${userId}_v1';
    final raw = await _storage.getJson(userSpecificKey);
    if (raw is List) {
      return raw
          .map((item) => FriendRequestModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    // Initial seeded incoming friend request from Kai Horizon
    final initialRequests = [
      FriendRequestModel(
        id: 'req_seed_kai_1',
        senderId: 'comp_2',
        senderName: 'Kai Horizon',
        senderTag: 'QST-1002',
        senderAvatarKey: 'avatar_sky_pilot',
        senderLevel: 5,
        receiverId: userId,
        receiverTag: 'MY_TAG',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
    await saveFriendRequests(initialRequests);
    return initialRequests;
  }

  @override
  Future<void> saveFriendRequests(List<FriendRequestModel> requests) async {
    final userId = await _getActiveUserId();
    final userSpecificKey = 'questup_friend_requests_${userId}_v1';
    final list = requests.map((r) => r.toJson()).toList();
    await _storage.saveJson(userSpecificKey, list);
    await _storage.saveJson(AppConstants.keyFriendRequests, list);
  }

  @override
  Future<List<FriendProfileModel>> getPlayerRegistry() async {
    final raw = await _storage.getJson(AppConstants.keyPlayerRegistry);
    List<FriendProfileModel> players = [];
    if (raw is List) {
      players = raw
          .map((item) => FriendProfileModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      players = _generateDefaultCompetitors();
      await savePlayerRegistry(players);
    }

    // Merge any locally registered users
    final localUsersRaw = await _storage.getJson(AppConstants.keyLocalUsers);
    if (localUsersRaw is Map<String, dynamic>) {
      for (final entry in localUsersRaw.entries) {
        final data = entry.value;
        if (data is Map<String, dynamic>) {
          final userId = data['id'] as String? ?? entry.key;
          final userName = data['name'] as String? ?? entry.key.split('@').first;
          final userTag = computePlayerTag(userId, entry.key);

          final exists = players.any((p) => p.userId == userId || p.playerTag == userTag);
          if (!exists) {
            players.add(
              FriendProfileModel(
                userId: userId,
                playerTag: userTag,
                name: userName,
                avatarKey: 'avatar_cyber_knight',
                level: 2,
                currentXp: 350,
                coins: 180,
                rank: players.length + 1,
                rankTitle: 'Scout Adventurer',
                completedQuestsCount: 2,
                gamesPlayedCount: 2,
                completedQuests: [
                  FriendCompletedQuestSummaryModel(
                    questId: 'q_local_1',
                    title: 'Discover Local City Hub',
                    category: 'Historical Landmark',
                    xpEarned: 150,
                    coinsEarned: 80,
                    completedAt: DateTime.now().subtract(const Duration(days: 1)),
                    locationName: 'City Center Plaza',
                  ),
                ],
                earnedBadges: [
                  FriendBadgeSummaryModel(
                    badgeId: 'badge_first_quest',
                    title: 'First Step into the Wild',
                    tier: 'Standard',
                    iconKey: 'badge_first_quest',
                    isHardcore: false,
                    unlockedAt: DateTime.now().subtract(const Duration(days: 1)),
                  ),
                ],
                friendshipDate: DateTime.now(),
                isOnline: true,
                lastActiveText: 'Active on Radar',
              ),
            );
          }
        }
      }
    }

    return players;
  }

  @override
  Future<void> savePlayerRegistry(List<FriendProfileModel> players) async {
    final list = players.map((p) => p.toJson()).toList();
    await _storage.saveJson(AppConstants.keyPlayerRegistry, list);
  }

  FriendProfileModel _getAriaSilverleafProfile() {
    return FriendProfileModel(
      userId: 'comp_4',
      playerTag: 'QST-1004',
      name: 'Aria Silverleaf',
      avatarKey: 'avatar_ranger',
      level: 3,
      currentXp: 1400,
      coins: 650,
      rank: 4,
      rankTitle: 'Trail Scout',
      completedQuestsCount: 7,
      gamesPlayedCount: 8,
      completedQuests: [
        FriendCompletedQuestSummaryModel(
          questId: 'quest_botanical_1',
          title: 'Echoes of the Ancient Botanical Gardens',
          category: 'Nature & Outdoors',
          xpEarned: 220,
          coinsEarned: 100,
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
          locationName: 'Royal Botanical Sanctuary',
        ),
        FriendCompletedQuestSummaryModel(
          questId: 'quest_clock_tower_2',
          title: 'The Great Heritage Clock Observation',
          category: 'Historical Landmark',
          xpEarned: 180,
          coinsEarned: 80,
          completedAt: DateTime.now().subtract(const Duration(days: 2)),
          locationName: 'Old Town Heritage Clock Tower',
        ),
        FriendCompletedQuestSummaryModel(
          questId: 'quest_art_gallery_3',
          title: 'Artisan Square Kinetic Mural Scan',
          category: 'Arts & Culture',
          xpEarned: 150,
          coinsEarned: 60,
          completedAt: DateTime.now().subtract(const Duration(days: 4)),
          locationName: 'Artisan Kinetic Gallery',
        ),
      ],
      earnedBadges: [
        FriendBadgeSummaryModel(
          badgeId: 'badge_first_quest',
          title: 'First Step into the Wild',
          tier: 'Standard',
          iconKey: 'badge_first_quest',
          isHardcore: false,
          unlockedAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        FriendBadgeSummaryModel(
          badgeId: 'badge_compass',
          title: 'Wayfinder Initiate',
          tier: 'Standard',
          iconKey: 'badge_compass',
          isHardcore: false,
          unlockedAt: DateTime.now().subtract(const Duration(days: 6)),
        ),
        FriendBadgeSummaryModel(
          badgeId: 'badge_trail',
          title: 'Pathfinder Vanguard',
          tier: 'Adept',
          iconKey: 'badge_trail',
          isHardcore: false,
          unlockedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      friendshipDate: DateTime.now().subtract(const Duration(days: 5)),
      isOnline: true,
      lastActiveText: 'Active on Radar',
    );
  }

  List<FriendProfileModel> _generateDefaultCompetitors() {
    return [
      FriendProfileModel(
        userId: 'comp_1',
        playerTag: 'QST-1001',
        name: 'Elena Shadowstride',
        avatarKey: 'avatar_mystic_sage',
        level: 6,
        currentXp: 3850,
        coins: 1950,
        rank: 1,
        rankTitle: 'Apex Mythic Explorer',
        completedQuestsCount: 18,
        gamesPlayedCount: 19,
        completedQuests: [
          FriendCompletedQuestSummaryModel(
            questId: 'quest_fortress_1',
            title: 'Fortress Citadel Bastion Ascent',
            category: 'Historical Landmark',
            xpEarned: 350,
            coinsEarned: 180,
            completedAt: DateTime.now().subtract(const Duration(hours: 4)),
            locationName: 'Ancient Hilltop Citadel',
          ),
          FriendCompletedQuestSummaryModel(
            questId: 'quest_whispering_woods',
            title: 'Whispering Canopy 10km Endurance Run',
            category: 'Fitness & Trail',
            xpEarned: 300,
            coinsEarned: 150,
            completedAt: DateTime.now().subtract(const Duration(days: 1)),
            locationName: 'Whispering Woods Trail',
          ),
          FriendCompletedQuestSummaryModel(
            questId: 'quest_midnight_enigma',
            title: 'Cyber Enigma Urban Code Decryption',
            category: 'Urban Mystery',
            xpEarned: 400,
            coinsEarned: 220,
            completedAt: DateTime.now().subtract(const Duration(days: 2)),
            locationName: 'Neon Plaza Arcade Vault',
          ),
        ],
        earnedBadges: [
          FriendBadgeSummaryModel(
            badgeId: 'badge_immortal_mythic',
            title: 'Immortal Mythic Legend',
            tier: 'Mythic',
            iconKey: 'badge_immortal_mythic',
            isHardcore: true,
            unlockedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          FriendBadgeSummaryModel(
            badgeId: 'badge_apex_titan',
            title: 'Apex Titan Explorer',
            tier: 'Hardcore',
            iconKey: 'badge_apex_titan',
            isHardcore: true,
            unlockedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
          FriendBadgeSummaryModel(
            badgeId: 'badge_crown',
            title: 'Grandmaster Champion',
            tier: 'Master',
            iconKey: 'badge_crown',
            isHardcore: false,
            unlockedAt: DateTime.now().subtract(const Duration(days: 7)),
          ),
        ],
        friendshipDate: DateTime.now().subtract(const Duration(days: 12)),
        isOnline: true,
        lastActiveText: 'Exploring Live Radar',
      ),
      FriendProfileModel(
        userId: 'comp_2',
        playerTag: 'QST-1002',
        name: 'Kai Horizon',
        avatarKey: 'avatar_sky_pilot',
        level: 5,
        currentXp: 2900,
        coins: 1400,
        rank: 2,
        rankTitle: 'Master Sky Voyager',
        completedQuestsCount: 14,
        gamesPlayedCount: 15,
        completedQuests: [
          FriendCompletedQuestSummaryModel(
            questId: 'quest_skylight_peak',
            title: 'Skylight Summit Ridge Recon',
            category: 'Nature & Outdoors',
            xpEarned: 280,
            coinsEarned: 130,
            completedAt: DateTime.now().subtract(const Duration(hours: 8)),
            locationName: 'Eagle Crest Lookout',
          ),
          FriendCompletedQuestSummaryModel(
            questId: 'quest_waterfront_run',
            title: 'Waterfront Promenade Sprint',
            category: 'Fitness & Trail',
            xpEarned: 220,
            coinsEarned: 100,
            completedAt: DateTime.now().subtract(const Duration(days: 2)),
            locationName: 'Marina Promenade',
          ),
        ],
        earnedBadges: [
          FriendBadgeSummaryModel(
            badgeId: 'badge_iron_legs',
            title: 'Iron Legs Ultra Trailblazer',
            tier: 'Hardcore',
            iconKey: 'badge_iron_legs',
            isHardcore: true,
            unlockedAt: DateTime.now().subtract(const Duration(days: 4)),
          ),
          FriendBadgeSummaryModel(
            badgeId: 'badge_dragon_gold',
            title: 'Dragon Hoard Tycoon',
            tier: 'Master',
            iconKey: 'badge_dragon_gold',
            isHardcore: true,
            unlockedAt: DateTime.now().subtract(const Duration(days: 9)),
          ),
        ],
        friendshipDate: DateTime.now().subtract(const Duration(days: 8)),
        isOnline: false,
        lastActiveText: '2 hours ago',
      ),
      FriendProfileModel(
        userId: 'comp_3',
        playerTag: 'QST-1003',
        name: 'Marcus Storm',
        avatarKey: 'avatar_fire_trail',
        level: 4,
        currentXp: 2100,
        coins: 980,
        rank: 3,
        rankTitle: 'Flame Vanguard',
        completedQuestsCount: 11,
        gamesPlayedCount: 12,
        completedQuests: [
          FriendCompletedQuestSummaryModel(
            questId: 'quest_iron_forge',
            title: 'Old Steam Foundry Industrial History',
            category: 'Historical Landmark',
            xpEarned: 240,
            coinsEarned: 110,
            completedAt: DateTime.now().subtract(const Duration(days: 1)),
            locationName: 'Heritage Foundry District',
          ),
        ],
        earnedBadges: [
          FriendBadgeSummaryModel(
            badgeId: 'badge_shield',
            title: 'Guardian Aegis',
            tier: 'Adept',
            iconKey: 'badge_shield',
            isHardcore: false,
            unlockedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ],
        friendshipDate: DateTime.now().subtract(const Duration(days: 6)),
        isOnline: false,
        lastActiveText: 'Yesterday',
      ),
      _getAriaSilverleafProfile(),
      FriendProfileModel(
        userId: 'comp_5',
        playerTag: 'QST-1005',
        name: 'Zane Deepcurrent',
        avatarKey: 'avatar_deep_diver',
        level: 2,
        currentXp: 850,
        coins: 420,
        rank: 5,
        rankTitle: 'Abyssal Scout',
        completedQuestsCount: 4,
        gamesPlayedCount: 5,
        completedQuests: [
          FriendCompletedQuestSummaryModel(
            questId: 'quest_lake_pier',
            title: 'Emerald Lake Pier Inspection',
            category: 'Nature & Outdoors',
            xpEarned: 160,
            coinsEarned: 70,
            completedAt: DateTime.now().subtract(const Duration(days: 3)),
            locationName: 'Emerald Lake Boat Basin',
          ),
        ],
        earnedBadges: [
          FriendBadgeSummaryModel(
            badgeId: 'badge_first_quest',
            title: 'First Step into the Wild',
            tier: 'Standard',
            iconKey: 'badge_first_quest',
            isHardcore: false,
            unlockedAt: DateTime.now().subtract(const Duration(days: 14)),
          ),
        ],
        friendshipDate: DateTime.now().subtract(const Duration(days: 4)),
        isOnline: true,
        lastActiveText: 'Active on Radar',
      ),
    ];
  }
}
