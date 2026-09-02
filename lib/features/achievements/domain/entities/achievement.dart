class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final String tier;
  final int requiredQuestCount;
  final int requiredLevel;
  final int requiredCoins;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    this.tier = 'NOVICE',
    this.requiredQuestCount = 0,
    this.requiredLevel = 1,
    this.requiredCoins = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  bool get isHardcore =>
      tier == 'HARDCORE' ||
      tier == 'MYTHIC' ||
      requiredLevel >= 4 ||
      requiredQuestCount >= 6 ||
      requiredCoins >= 1000;

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconKey,
    String? tier,
    int? requiredQuestCount,
    int? requiredLevel,
    int? requiredCoins,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      tier: tier ?? this.tier,
      requiredQuestCount: requiredQuestCount ?? this.requiredQuestCount,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      requiredCoins: requiredCoins ?? this.requiredCoins,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
