import '../../domain/entities/friend_profile.dart';

class FriendCompletedQuestSummaryModel extends FriendCompletedQuestSummary {
  const FriendCompletedQuestSummaryModel({
    required super.questId,
    required super.title,
    required super.category,
    required super.xpEarned,
    required super.coinsEarned,
    required super.completedAt,
    required super.locationName,
  });

  factory FriendCompletedQuestSummaryModel.fromJson(Map<String, dynamic> json) {
    return FriendCompletedQuestSummaryModel(
      questId: json['questId'] as String? ?? json['quest_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Adventure Quest',
      category: json['category'] as String? ?? 'Exploration',
      xpEarned: int.tryParse(json['xpEarned']?.toString() ?? json['xp_earned']?.toString() ?? '') ?? 50,
      coinsEarned: int.tryParse(json['coinsEarned']?.toString() ?? json['coins_earned']?.toString() ?? '') ?? 25,
      completedAt: json['completedAt'] != null
          ? (DateTime.tryParse(json['completedAt'] as String) ?? DateTime.now())
          : (json['completed_at'] != null
              ? (DateTime.tryParse(json['completed_at'] as String) ?? DateTime.now())
              : DateTime.now()),
      locationName: json['locationName'] as String? ?? json['location_name'] as String? ?? 'Landmark',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questId': questId,
      'title': title,
      'category': category,
      'xpEarned': xpEarned,
      'coinsEarned': coinsEarned,
      'completedAt': completedAt.toIso8601String(),
      'locationName': locationName,
    };
  }
}

class FriendBadgeSummaryModel extends FriendBadgeSummary {
  const FriendBadgeSummaryModel({
    required super.badgeId,
    required super.title,
    required super.tier,
    required super.iconKey,
    required super.isHardcore,
    super.unlockedAt,
  });

  factory FriendBadgeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FriendBadgeSummaryModel(
      badgeId: json['badgeId'] as String? ?? '',
      title: json['title'] as String? ?? 'Explorer Badge',
      tier: json['tier'] as String? ?? 'Standard',
      iconKey: json['iconKey'] as String? ?? 'badge_compass',
      isHardcore: json['isHardcore'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'badgeId': badgeId,
      'title': title,
      'tier': tier,
      'iconKey': iconKey,
      'isHardcore': isHardcore,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }
}

class FriendProfileModel extends FriendProfile {
  const FriendProfileModel({
    required super.userId,
    required super.playerTag,
    required super.name,
    required super.avatarKey,
    required super.level,
    required super.currentXp,
    required super.coins,
    required super.rank,
    required super.rankTitle,
    required super.completedQuestsCount,
    required super.gamesPlayedCount,
    required super.completedQuests,
    required super.earnedBadges,
    required super.friendshipDate,
    required super.isOnline,
    required super.lastActiveText,
    super.isFriend = false,
    super.friendshipStatus = 'none',
  });

  factory FriendProfileModel.fromJson(Map<String, dynamic> json) {
    return FriendProfileModel(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      playerTag: json['playerTag'] as String? ?? json['player_id'] as String? ?? 'QST-0000',
      name: json['name'] as String? ?? json['username'] as String? ?? 'Explorer',
      avatarKey: json['avatarKey'] as String? ?? json['avatar_key'] as String? ?? 'avatar_1',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? json['current_xp'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      rank: json['rank'] as int? ?? 99,
      rankTitle: json['rankTitle'] as String? ?? json['rank_title'] as String? ?? 'Scout',
      completedQuestsCount: json['completedQuestsCount'] as int? ?? json['completed_quests_count'] as int? ?? 0,
      gamesPlayedCount: json['gamesPlayedCount'] as int? ?? json['games_played_count'] as int? ?? 0,
      completedQuests: (json['completedQuests'] as List<dynamic>?)
              ?.map((e) => FriendCompletedQuestSummaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      earnedBadges: (json['earnedBadges'] as List<dynamic>?)
              ?.map((e) => FriendBadgeSummaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      friendshipDate: json['friendshipDate'] != null
          ? (DateTime.tryParse(json['friendshipDate'] as String) ?? DateTime.now())
          : (json['friendship_date'] != null
              ? (DateTime.tryParse(json['friendship_date'] as String) ?? DateTime.now())
              : DateTime.now()),
      isOnline: json['isOnline'] as bool? ?? (json['is_online'] == 1 || json['is_online'] == true),
      lastActiveText: json['lastActiveText'] as String? ?? json['last_active'] as String? ?? 'Recently active',
      isFriend: json['isFriend'] as bool? ?? (json['friendship_status'] == 'accepted' || json['is_friend'] == true),
      friendshipStatus: json['friendshipStatus'] as String? ?? json['friendship_status'] as String? ?? (json['isFriend'] == true ? 'accepted' : 'none'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'playerTag': playerTag,
      'name': name,
      'avatarKey': avatarKey,
      'level': level,
      'currentXp': currentXp,
      'coins': coins,
      'rank': rank,
      'rankTitle': rankTitle,
      'completedQuestsCount': completedQuestsCount,
      'gamesPlayedCount': gamesPlayedCount,
      'completedQuests': completedQuests
          .map((e) => (e is FriendCompletedQuestSummaryModel)
              ? e.toJson()
              : FriendCompletedQuestSummaryModel(
                  questId: e.questId,
                  title: e.title,
                  category: e.category,
                  xpEarned: e.xpEarned,
                  coinsEarned: e.coinsEarned,
                  completedAt: e.completedAt,
                  locationName: e.locationName,
                ).toJson())
          .toList(),
      'earnedBadges': earnedBadges
          .map((e) => (e is FriendBadgeSummaryModel)
              ? e.toJson()
              : FriendBadgeSummaryModel(
                  badgeId: e.badgeId,
                  title: e.title,
                  tier: e.tier,
                  iconKey: e.iconKey,
                  isHardcore: e.isHardcore,
                  unlockedAt: e.unlockedAt,
                ).toJson())
          .toList(),
      'friendshipDate': friendshipDate.toIso8601String(),
      'isOnline': isOnline,
      'lastActiveText': lastActiveText,
      'isFriend': isFriend,
      'friendshipStatus': friendshipStatus,
    };
  }

  @override
  FriendProfileModel copyWith({
    String? userId,
    String? playerTag,
    String? name,
    String? avatarKey,
    int? level,
    int? currentXp,
    int? coins,
    int? rank,
    String? rankTitle,
    int? completedQuestsCount,
    int? gamesPlayedCount,
    List<FriendCompletedQuestSummary>? completedQuests,
    List<FriendBadgeSummary>? earnedBadges,
    DateTime? friendshipDate,
    bool? isOnline,
    String? lastActiveText,
    bool? isFriend,
    String? friendshipStatus,
  }) {
    return FriendProfileModel(
      userId: userId ?? this.userId,
      playerTag: playerTag ?? this.playerTag,
      name: name ?? this.name,
      avatarKey: avatarKey ?? this.avatarKey,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      coins: coins ?? this.coins,
      rank: rank ?? this.rank,
      rankTitle: rankTitle ?? this.rankTitle,
      completedQuestsCount: completedQuestsCount ?? this.completedQuestsCount,
      gamesPlayedCount: gamesPlayedCount ?? this.gamesPlayedCount,
      completedQuests: completedQuests ?? this.completedQuests,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      friendshipDate: friendshipDate ?? this.friendshipDate,
      isOnline: isOnline ?? this.isOnline,
      lastActiveText: lastActiveText ?? this.lastActiveText,
      isFriend: isFriend ?? this.isFriend,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
    );
  }
}
