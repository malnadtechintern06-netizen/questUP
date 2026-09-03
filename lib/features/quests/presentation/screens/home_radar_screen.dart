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

class _HomeRadarScreenState extends ConsumerState<HomeRadarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoAcquireLocation();
    });
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

    final userName = userProfileAsync.valueOrNull?.name ?? 'Explorer';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        onOpenGpsSimulator: () => _showGpsSimulatorDialog(context, ref),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed: () {
              Scaffold.of(scaffoldContext).openDrawer();
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Good morning, $userName!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('👋', style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              'Your world is your adventure',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quest Activity Calendar',
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.secondary,
            ),
            onPressed: () => context.push(RoutePaths.calendar),
          ),
          IconButton(
            tooltip: 'GPS Simulation Tool',
            icon: Icon(
              Icons.satellite_alt_rounded,
              color: isSimulated ? AppColors.secondary : AppColors.primary,
            ),
            onPressed: () => _showGpsSimulatorDialog(context, ref),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                onPressed: () => NotificationsSheet.show(context),
              ),
              if (unreadNotifsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.accentDanger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadNotifsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
              // 1. Hero Gamer Banner Card with Level, XP, and 3D Coin Badge
              userProfileAsync.when(
                data: (profile) => _buildHeroGamerCard(context, profile),
                loading: () => const ShimmerBox(width: double.infinity, height: 210, borderRadius: 22),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 18),

              // 2. Quest Activity Calendar Widget
              const HomeCalendarWidget(),

              const SizedBox(height: 22),

              // 3. Nearby Adventures Section (Horizontal Floating 3D Cards)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.explore_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nearby Adventures',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleLarge.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (activeGps != null)
                    InkWell(
                      onTap: () => context.go(RoutePaths.quests),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'View all →',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
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

                  loading: () => SizedBox(
                    height: 260,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: ShimmerBox(width: 175, height: 260, borderRadius: 20),
                      ),
                    ),
                  ),
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

                // Location Details Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationDetailsAsync.valueOrNull?.areaName ?? 'Live GPS Location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(fontSize: 13),
                            ),
                            Text(
                              locationDetailsAsync.valueOrNull?.formattedAddress ??
                                  'GPS: ${activeGps.latitude.toStringAsFixed(4)}, ${activeGps.longitude.toStringAsFixed(4)}',
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
                const SizedBox(height: 36),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroGamerCard(BuildContext context, dynamic profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Image with Cinematic Overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                child: SizedBox(
                  height: 155,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/hero_poster.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceElevated,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        AppColors.surface.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 16,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'EXPLORER DASHBOARD',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Turn the World Into Your Game.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Coins Pill at Top Right of Hero
              Positioned(
                top: 14,
                right: 14,
                child: CoinCounter3D(
                  coins: profile.coins,
                ),
              ),
            ],
          ),

          // XP Progress Bar and Rank Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: AnimatedXpBar(
              currentXp: profile.currentXp,
              requiredXp: profile.xpToNextLevel,
              level: profile.level,
            ),
          ),
        ],
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


