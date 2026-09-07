import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/maps_launcher_service.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/animated_xp_bar.dart';
import 'package:quest_up/core/widgets/app_drawer.dart';
import 'package:quest_up/core/widgets/coin_counter_3d.dart';
import 'package:quest_up/core/widgets/custom_button.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
import 'package:quest_up/core/widgets/glassmorphic_card.dart';
import 'package:quest_up/core/widgets/quest_rarity_badge.dart';
import 'package:quest_up/core/widgets/shimmer_loading.dart';
import 'package:quest_up/features/calendar/presentation/providers/quest_calendar_providers.dart';
import 'package:quest_up/features/calendar/presentation/widgets/home_calendar_widget.dart';
import 'package:quest_up/features/location_permission/presentation/providers/location_permission_provider.dart';
import 'package:quest_up/features/notifications/presentation/providers/notification_providers.dart';
import 'package:quest_up/features/notifications/presentation/widgets/notifications_sheet.dart';
import 'package:quest_up/features/profile/domain/entities/user_profile.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';
import 'package:quest_up/features/quests/presentation/widgets/category_filter_chips.dart';
import 'package:quest_up/features/quests/presentation/widgets/google_maps_marker_card_widget.dart';
import 'package:quest_up/features/quests/presentation/widgets/quest_card_widget.dart';
import 'package:quest_up/features/quests/presentation/widgets/radar_display_widget.dart';

class HomeRadarScreen extends ConsumerStatefulWidget {
  const HomeRadarScreen({super.key});

  @override
  ConsumerState<HomeRadarScreen> createState() => _HomeRadarScreenState();
}

class _HomeRadarScreenState extends ConsumerState<HomeRadarScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[TIMING] HOME SCREEN READY');
      _checkAndAutoAcquireLocation();
      ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HOME RADAR] App resumed, refreshing quests');
      ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAndAutoAcquireLocation() async {
    final activeGps = ref.read(activeGpsCoordinatesProvider);
    if (activeGps == null) {
      final locService = ref.read(locationServiceProvider);
      final isReady = await locService.isLocationEnabledAndPermitted();
      if (isReady && mounted) {
        ref.read(questsNotifierProvider.notifier).fetchQuests(showLoading: false);
      }
    }
  }

  void _showGpsSimulatorDialog(BuildContext context, WidgetRef ref) {
    final currentGps = ref.read(activeGpsCoordinatesProvider);
    final latController = TextEditingController(
        text: currentGps?.latitude.toStringAsFixed(4) ?? '12.9716');
    final lonController = TextEditingController(
        text: currentGps?.longitude.toStringAsFixed(4) ?? '77.5946');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.satellite_alt_rounded, color: AppColors.accentLocation),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'GPS Simulator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleLarge,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test quest proximity or teleport to custom GPS coordinates:',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        labelStyle: AppTypography.caption,
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lonController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        labelStyle: AppTypography.caption,
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'SET COORDINATES',
                width: double.infinity,
                onPressed: () {
                  final lat = double.tryParse(latController.text);
                  final lon = double.tryParse(lonController.text);
                  if (lat != null && lon != null) {
                    ref.read(questsNotifierProvider.notifier).simulateLocation(lat, lon);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Simulated at Lat: $lat, Lon: $lon')),
                    );
                  }
                },
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              Text('Quick Testing Presets:',
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                title: Text('At Proximity Beacon (~50m In Range)', style: AppTypography.bodyMedium),
                onTap: () {
                  if (currentGps != null) {
                    ref.read(questsNotifierProvider.notifier).simulateLocation(
                          currentGps.latitude + 0.00045,
                          currentGps.longitude + 0.00035,
                        );
                  } else {
                    ref.read(questsNotifierProvider.notifier).simulateLocation(12.9720, 77.5950);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Simulated at Beacon (~50m In Range!)')),
                  );
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gps_fixed, color: AppColors.accentSuccess),
                title: Text('Reset to Real Device GPS', style: AppTypography.bodyMedium),
                onTap: () {
                  ref.read(questsNotifierProvider.notifier).resetSimulatedLocation();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to real hardware GPS coordinates.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDisplayName(String name) {
    if (name.trim().isEmpty) return 'Explorer';
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good evening';
  }

  String _getTimeEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '🌅';
    if (hour >= 12 && hour < 17) return '☀️';
    if (hour >= 17 && hour < 21) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileNotifierProvider);
    final questsAsync = ref.watch(questsNotifierProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final filteredQuests = ref.watch(filteredQuestsProvider);
    final activeGps = ref.watch(activeGpsCoordinatesProvider);
    final isSimulated = ref.watch(locationServiceProvider).isSimulated;
    final locationDetailsAsync = ref.watch(liveLocationDetailsProvider);
    final unreadNotifsCount = ref.watch(unreadNotificationsCountProvider);

    final rawUserName = userProfileAsync.valueOrNull?.name ?? 'Explorer';
    final userName = _formatDisplayName(rawUserName);
    final timeGreeting = _getTimeGreeting();
    final timeEmoji = _getTimeEmoji();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        onOpenGpsSimulator: () => _showGpsSimulatorDialog(context, ref),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed: () {
              Scaffold.of(scaffoldContext).openDrawer();
            },
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_rounded, color: AppColors.primary, size: 15),
              const SizedBox(width: 5),
              Text(
                'QuestUP',
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Quest Activity Calendar',
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.secondary,
              size: 21,
            ),
            onPressed: () => context.push(RoutePaths.calendar),
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'GPS Simulation Tool',
            icon: Icon(
              Icons.satellite_alt_rounded,
              color: isSimulated ? AppColors.secondary : AppColors.primary,
              size: 21,
            ),
            onPressed: () => _showGpsSimulatorDialog(context, ref),
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests();
          await ref.read(userProfileNotifierProvider.notifier).loadProfile();
          await ref.read(questCalendarNotifierProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. High-Impact Player Hero Greeting Header
              _buildPlayerGreetingHeader(
                greeting: timeGreeting,
                formattedName: userName,
                emoji: timeEmoji,
                profile: userProfileAsync.valueOrNull,
              ),
              const SizedBox(height: 12),

              // 1. Hero Gamer Banner Card with Level, XP, and 3D Coin Badge (Rendered Instantly)
              _buildHeroGamerCard(
                context,
                userProfileAsync.valueOrNull ??
                    UserProfile(
                      id: 'guest',
                      name: 'Explorer',
                      email: '',
                      avatarKey: 'avatar_ranger',
                      level: 1,
                      currentXp: 0,
                      xpToNextLevel: 1000,
                      coins: 100,
                      completedQuestIds: const [],
                      earnedBadgeIds: const [],
                      joinedAt: DateTime(2025, 1, 1),
                    ),
              ),

              const SizedBox(height: 18),

              // 2. Quest Activity Calendar Widget
              const HomeCalendarWidget(),

              const SizedBox(height: 22),

              // 3. Nearby Adventures Section (Horizontal Floating 3D Cards)
              Builder(
                builder: (context) {
                  final allQuests = questsAsync.valueOrNull ?? [];
                  final availableCount = allQuests.where((q) => q.isActive && !q.isCompleted).length;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.explore_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Nearby Adventures',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleLarge.copyWith(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '$availableCount avail',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activeGps != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => context.go(RoutePaths.quests),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'View all →',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),


              // If GPS is not active, display location prompt card
              if (activeGps == null)
                _buildLocationRequiredCard(context, ref)
              else
                questsAsync.when(
                  data: (quests) {
                    final activeQuests = quests.where((q) => !q.isCompleted).toList();
                    if (activeQuests.isEmpty) {
                      return GlassmorphicCard(
                        padding: const EdgeInsets.all(22),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.stars_rounded, size: 36, color: AppColors.secondary),
                              const SizedBox(height: 10),
                              Text(
                                quests.isNotEmpty ? 'All Nearby Quests Completed! 🎉' : 'No adventures nearby',
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                quests.isNotEmpty
                                    ? 'Great job! Check your Completed tab or move around to discover new quests.'
                                    : 'Move around your neighborhood to discover new quests.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: activeQuests.length,
                        itemBuilder: (context, index) {
                          final quest = activeQuests[index];
                          return _buildAdventure3DCard(context, quest);
                        },
                      ),
                    );
                  },

                  loading: () {
                    final cached = questsAsync.valueOrNull;
                    if (cached != null && cached.isNotEmpty) {
                      final activeQuests = cached.where((q) => !q.isCompleted).toList();
                      return SizedBox(
                        height: 260,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: activeQuests.length,
                          itemBuilder: (context, index) {
                            final quest = activeQuests[index];
                            return _buildAdventure3DCard(context, quest);
                          },
                        ),
                      );
                    }
                    return SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        itemBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: ShimmerBox(width: 175, height: 260, borderRadius: 20),
                        ),
                      ),
                    );
                  },
                  error: (err, stack) => ErrorStateWidget(
                    message: 'Failed to load nearby quests',
                    onRetry: () =>
                        ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests(),
                  ),
                ),

              const SizedBox(height: 24),

              // 4. Daily Progress Section
              _buildDailyProgressSection(context),

              const SizedBox(height: 24),

              // 5. Live Tactical GPS Proximity Radar
              if (activeGps != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.satellite_alt_rounded, size: 18, color: AppColors.accentLocation),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live GPS Proximity Radar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () =>
                          ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests(),
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Refresh',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Location Details Bar (Current Location HUD)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderBright, width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentSuccess.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accentSuccess.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.my_location_rounded,
                            size: 18, color: AppColors.accentSuccess),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'CURRENT LOCATION',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentSuccess,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'LIVE GPS',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              locationDetailsAsync.valueOrNull?.areaName ?? 'Current Location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              locationDetailsAsync.valueOrNull?.formattedAddress ??
                                  'GPS: ${activeGps.latitude.toStringAsFixed(4)}°, ${activeGps.longitude.toStringAsFixed(4)}°',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                        tooltip: 'View in Google Maps',
                        onPressed: () {
                          ref.read(mapsLauncherServiceProvider).openGoogleMapsLocation(
                                activeGps.latitude,
                                activeGps.longitude,
                                label: locationDetailsAsync.valueOrNull?.areaName ?? 'My Location',
                              );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Radar Display
                questsAsync.when(
                  data: (quests) => RadarDisplayWidget(
                    quests: quests,
                    userCoordinates: activeGps,
                    onSelectQuest: (quest) {
                      context.push(RoutePaths.questDetailPath(quest.id));
                    },
                  ),
                  loading: () =>
                      const ShimmerBox(width: double.infinity, height: 250, borderRadius: 24),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
              ],

              // 6. Category Chips & Quests List
              if (activeGps != null) ...[
                CategoryFilterChips(
                  selectedCategory: selectedCategory,
                  onSelected: (cat) {
                    ref.read(selectedCategoryProvider.notifier).state = cat;
                  },
                ),
                const SizedBox(height: 12),

                ...filteredQuests.map(
                  (quest) => QuestCardWidget(
                    quest: quest,
                    onTap: () {
                      context.push(RoutePaths.questDetailPath(quest.id));
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ] else ...[
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerGreetingHeader({
    required String greeting,
    required String formattedName,
    required String emoji,
    UserProfile? profile,
  }) {
    final level = profile?.level ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '$greeting,',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$formattedName!',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your world is your adventure',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Level / Rank Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accentSuccess,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'LVL $level',
                  style: AppTypography.badge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroGamerCard(BuildContext context, dynamic profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: AspectRatio(
          aspectRatio: 459 / 874,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Hero Vertical Adventure Artwork (Clean, unmarred, perfect fit)
              Image.asset(
                'assets/images/hero_card.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/hero_poster.jpg',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Live Dynamic Coins Overlay (aligned with QuestUP logo at top right)
              Positioned(
                top: 36,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1B2E).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFFFD700),
                        size: 19,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${profile.coins} COINS',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Live Dynamic Level & XP Overlay (positioned with ample padding in the bottom card area)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Live Level Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Colors.black, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                'LVL ${profile.level}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Live XP Counter
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF), size: 17),
                            const SizedBox(width: 3),
                            Text(
                              '${profile.currentXp} / ${profile.xpToNextLevel} XP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Live XP Track Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF08192D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final pct = profile.xpToNextLevel > 0
                                ? (profile.currentXp / profile.xpToNextLevel).clamp(0.0, 1.0)
                                : 0.0;
                            return Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: pct,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdventure3DCard(BuildContext context, Quest quest) {
    final distStr = DistanceCalculator.formatDistance(quest.distanceMeters ?? 0);

    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.push(RoutePaths.questDetailPath(quest.id)),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real Place Photo / Google Maps Location Marker Preview
              Stack(
                children: [
                  GoogleMapsMarkerCardWidget(
                    quest: quest,
                    height: 110,
                    width: double.infinity,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: QuestRarityBadge.fromDifficulty(quest.difficulty),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_outline_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),

              // Info & Action
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      quest.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            distStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '+${quest.xpReward} XP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accentXp,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '+${quest.coinReward} 🪙',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'START QUEST →',
                        style: AppTypography.badge.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyProgressSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Daily Challenges',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '1 / 3 completed',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),


          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.33,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),

          // Tasks List
          _buildDailyTaskItem(
            icon: Icons.location_on_rounded,
            title: 'Explore a new landmark',
            xp: '+50 XP',
            isCompleted: true,
          ),
          const Divider(height: 14, color: AppColors.divider),
          _buildDailyTaskItem(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan 3 locations on radar',
            xp: '+30 XP',
            isCompleted: false,
          ),
          const Divider(height: 14, color: AppColors.divider),
          _buildDailyTaskItem(
            icon: Icons.camera_alt_rounded,
            title: 'Capture verified photo proof',
            xp: '+20 XP',
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskItem({
    required IconData icon,
    required String title,
    required String xp,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primaryLight : AppColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isCompleted ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                xp,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(
          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isCompleted ? AppColors.primary : AppColors.textMuted,
          size: 22,
        ),
      ],
    );
  }

  Widget _buildLocationRequiredCard(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Enable Location to View Quests',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quests will load and appear as soon as your device location is turned on.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'TURN ON LOCATION',
            icon: Icons.my_location_rounded,
            width: double.infinity,
            onPressed: () async {
              final notifier = ref.read(locationPermissionNotifierProvider.notifier);
              final success = await notifier.requestAndAcquireLocation();
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Please enable GPS and location permissions in device settings to load quests.',
                    ),
                    action: SnackBarAction(
                      label: 'SETTINGS',
                      onPressed: () => notifier.openAppSettings(),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}


