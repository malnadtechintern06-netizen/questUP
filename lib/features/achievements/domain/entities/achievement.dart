class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconKey;
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
    this.requiredQuestCount = 0,
    this.requiredLevel = 1,
    this.requiredCoins = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconKey,
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
      requiredQuestCount: requiredQuestCount ?? this.requiredQuestCount,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      requiredCoins: requiredCoins ?? this.requiredCoins,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
