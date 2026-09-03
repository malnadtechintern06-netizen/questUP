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
      questId: json['questId'] as String? ?? '',
      title: json['title'] as String? ?? 'Adventure Quest',
      category: json['category'] as String? ?? 'Exploration',
      xpEarned: json['xpEarned'] as int? ?? 50,
      coinsEarned: json['coinsEarned'] as int? ?? 25,
      completedAt: json['completedAt'] != null
          ? (DateTime.tryParse(json['completedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      locationName: json['locationName'] as String? ?? 'Landmark',
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
  });

  factory FriendProfileModel.fromJson(Map<String, dynamic> json) {
    return FriendProfileModel(
      userId: json['userId'] as String? ?? '',
      playerTag: json['playerTag'] as String? ?? 'QST-0000',
      name: json['name'] as String? ?? 'Explorer',
      avatarKey: json['avatarKey'] as String? ?? 'avatar_1',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      rank: json['rank'] as int? ?? 99,
      rankTitle: json['rankTitle'] as String? ?? 'Scout',
      completedQuestsCount: json['completedQuestsCount'] as int? ?? 0,
      gamesPlayedCount: json['gamesPlayedCount'] as int? ?? 0,
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
          : DateTime.now(),
      isOnline: json['isOnline'] as bool? ?? false,
      lastActiveText: json['lastActiveText'] as String? ?? 'Recently active',
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
    };
  }
}
