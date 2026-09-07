import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/empty_state_widget.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/notifications/presentation/providers/notification_providers.dart';
import 'package:quest_up/features/notifications/presentation/widgets/notifications_sheet.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/quests/presentation/widgets/category_filter_chips.dart';
import 'package:quest_up/features/quests/presentation/widgets/quest_card_widget.dart';

final statusFilterProvider = StateProvider<String>((ref) => 'all'); // 'all', 'available', 'completed'

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(searchQueryProvider));
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[QUEST SCREEN] Screen opened, requesting latest quests from API');
      ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[QUEST SCREEN] App resumed, requesting latest quests from API');
      ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuestSearch(Quest q, String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return true;

    final searchSpace = [
      q.title,
      q.locationName,
      q.description,
      q.category.name,
      q.placeAddress ?? '',
      q.originLocationName ?? '',
      q.storyline,
      q.historicalFact ?? '',
      q.sourceType,
      q.difficulty.name,
      q.verificationType.name,
    ].join(' ').toLowerCase();

    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return tokens.every((token) => searchSpace.contains(token));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (_searchController.text != next) {
        _searchController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final questsAsync = ref.watch(questsNotifierProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final query = ref.watch(searchQueryProvider);
    final activeGps = ref.watch(activeGpsCoordinatesProvider);
    final maxRadius = ref.watch(maxRadiusFilterMetersProvider);
    final unreadNotifsCount = ref.watch(unreadNotificationsCountProvider);

    final allQuests = questsAsync.valueOrNull ?? [];
    final availableCount = allQuests.where((q) => q.isActive && !q.isCompleted).length;
    final completedCount = allQuests.where((q) => q.isActive && q.isCompleted).length;
    final totalCount = allQuests.where((q) => q.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Text(
          'Quest Log',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Quest Activity Calendar',
            icon: const Icon(Icons.calendar_month_rounded, color: AppColors.secondary, size: 21),
            onPressed: () => context.push(RoutePaths.calendar),
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Refresh Quests',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 21),
            onPressed: () =>
                ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests(),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 21),
                onPressed: () => NotificationsSheet.show(context),
              ),
              if (unreadNotifsCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.accentDanger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadNotifsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Live GPS coordinate banner
          if (activeGps != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.satellite_alt_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS: ${activeGps.latitude.toStringAsFixed(4)}, ${activeGps.longitude.toStringAsFixed(4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(maxRadius / 1000).toStringAsFixed(0)}km Scan',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search quests by title, landmark, or category...',
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Category Chips
          CategoryFilterChips(
            selectedCategory: selectedCategory,
            onSelected: (cat) => ref.read(selectedCategoryProvider.notifier).state = cat,
          ),
          const SizedBox(height: 8),

          // Status segmented buttons (3D Pill Tabs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusTab(
                  label: 'All ($totalCount)',
                  value: 'all',
                  isSelected: statusFilter == 'all',
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  label: 'Available ($availableCount)',
                  value: 'available',
                  isSelected: statusFilter == 'available',
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  label: 'Completed ($completedCount)',
                  value: 'completed',
                  isSelected: statusFilter == 'completed',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List of quests (Closest first or all active quests)
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref
                    .read(questsNotifierProvider.notifier)
                    .fetchQuests(showLoading: false);
              },
              child: questsAsync.when(
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    QuestCardShimmer(),
                    QuestCardShimmer(),
                    QuestCardShimmer(),
                  ],
                ),
                error: (err, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 40),
                    ErrorStateWidget(
                      message: err.toString(),
                      onRetry: () => ref
                          .read(questsNotifierProvider.notifier)
                          .refreshLocationAndQuests(),
                    ),
                  ],
                ),
                data: (quests) {
                  final filtered = quests.where((q) {
                    if (!q.isActive) return false;
                    final matchesCat =
                        selectedCategory == null || q.category == selectedCategory;
                    final matchesQuery = _matchesQuestSearch(q, query);
                    final matchesStatus = statusFilter == 'all'
                        ? true
                        : (statusFilter == 'completed' ? q.isCompleted : !q.isCompleted);
                    return matchesCat && matchesQuery && matchesStatus;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        EmptyStateWidget(
                          title: 'No Quests Found',
                          description:
                              'No quests matching your filters. Try pulling to refresh or clearing search.',
                          actionText: 'Reset Filters',
                          onAction: () {
                            _searchController.clear();
                            ref.read(selectedCategoryProvider.notifier).state = null;
                            ref.read(searchQueryProvider.notifier).state = '';
                            ref.read(statusFilterProvider.notifier).state = 'all';
                            ref
                                .read(questsNotifierProvider.notifier)
                                .fetchQuests(showLoading: true);
                          },
                        ),
                      ],
                    );
                  }

                  final locationQuests = filtered.where((q) => q.sourceType != 'admin').toList();
                  final adminQuests = filtered.where((q) => q.sourceType == 'admin').toList();

                  final listChildren = <Widget>[];

                  if (locationQuests.isNotEmpty) {
                    listChildren.add(_buildSectionHeader(
                      'LOCATION QUESTS (10 KM RADIUS)',
                      '${locationQuests.length} Nearby',
                      Icons.explore_rounded,
                      AppColors.accentLocation,
                    ));
                    for (final q in locationQuests) {
                      listChildren.add(QuestCardWidget(
                        quest: q,
                        onTap: () => context.push(RoutePaths.questDetailPath(q.id)),
                      ));
                    }
                  }

                  if (adminQuests.isNotEmpty) {
                    listChildren.add(_buildSectionHeader(
                      'GLOBAL ADMIN QUESTS',
                      '${adminQuests.length} Challenges',
                      Icons.stars_rounded,
                      AppColors.secondary,
                    ));
                    for (final q in adminQuests) {
                      listChildren.add(QuestCardWidget(
                        quest: q,
                        onTap: () => context.push(RoutePaths.questDetailPath(q.id)),
                      ));
                    }
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: listChildren.length,
                    itemBuilder: (context, index) => listChildren[index],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String countText,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.badge.copyWith(
                color: color,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              countText,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(statusFilterProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
