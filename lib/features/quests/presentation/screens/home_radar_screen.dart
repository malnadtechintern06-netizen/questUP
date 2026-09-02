import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/maps_launcher_service.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';
import 'package:quest_up/core/widgets/app_drawer.dart';
import 'package:quest_up/core/widgets/custom_button.dart';
import 'package:quest_up/core/widgets/error_state_widget.dart';
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
              const SizedBox(height: 10),
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
        backgroundColor: AppColors.background,
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
                      fontWeight: FontWeight.bold,
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
              'Ready for your next adventure?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
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
        onRefresh: () async {
          await ref.read(questsNotifierProvider.notifier).refreshLocationAndQuests();
          await ref.read(userProfileNotifierProvider.notifier).loadProfile();
          await ref.read(questCalendarNotifierProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Banner Card with Level, XP, and Coins Badges
              userProfileAsync.when(
                data: (profile) => _buildHeroBannerCard(context, profile),
                loading: () => const ShimmerBox(width: double.infinity, height: 210, borderRadius: 20),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 18),

              // 2. Quest Activity Calendar Widget
              const HomeCalendarWidget(),

              const SizedBox(height: 22),

              // 3. Nearby Adventures Header & View All button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nearby Adventures',
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (activeGps != null)
                    InkWell(
                      onTap: () => context.go(RoutePaths.quests),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'View all',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // If GPS is not yet active/enabled, display the Location Required Card instead of quests
              if (activeGps == null)
                _buildLocationRequiredCard(context, ref)
              else
                // Horizontal Scrollable Cards for Nearby Discovered Landmarks
                questsAsync.when(
                  data: (quests) {
                    if (quests.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            'No nearby quests found. Move to another location to discover new quests.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 235,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quests.length,
                        itemBuilder: (context, index) {
                          final quest = quests[index];
                          return _buildAdventureCard(context, quest);
                        },
                      ),
                    );
                  },
                  loading: () => SizedBox(
                    height: 235,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: ShimmerBox(width: 150, height: 235, borderRadius: 18),
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

              // 3. Daily Progress Section
              _buildDailyProgressSection(context),

              const SizedBox(height: 24),

              // 4. Live Tracked GPS Location Banner & Interactive Proximity Radar
              if (activeGps != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live GPS Proximity Radar',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
                const SizedBox(height: 8),

                // Location Details Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 10),

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
                      const ShimmerBox(width: double.infinity, height: 240, borderRadius: 24),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Category Chips & Quests List
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
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBannerCard(BuildContext context, dynamic profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Image with Overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/hero_poster.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.68),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DAILY MOTIVATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keep Exploring.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Keep Growing.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          // Stats Row: Level, XP, Coins
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBadge(
                    icon: Icons.navigation_rounded,
                    iconColor: AppColors.primary,
                    badgeBg: AppColors.primaryLight,
                    label: 'Level',
                    value: '${profile.level}',
                  ),
                ),
                Container(height: 28, width: 1, color: AppColors.border),
                Expanded(
                  child: _buildStatBadge(
                    icon: Icons.water_drop_rounded,
                    iconColor: AppColors.accentXp,
                    badgeBg: const Color(0xFFEFF6FF),
                    label: 'XP',
                    value: '${profile.currentXp}/${profile.xpToNextLevel}',
                  ),
                ),
                Container(height: 28, width: 1, color: AppColors.border),
                Expanded(
                  child: _buildStatBadge(
                    icon: Icons.monetization_on_rounded,
                    iconColor: AppColors.secondary,
                    badgeBg: const Color(0xFFFEF3C7),
                    label: 'Coins',
                    value: '${profile.coins}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdventureCard(BuildContext context, Quest quest) {
    final distStr = DistanceCalculator.formatDistance(quest.distanceMeters ?? 0);

    return Container(
      width: 145,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push(RoutePaths.questDetailPath(quest.id)),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Google Maps Location Marker Preview with Bookmark button
            Stack(
              children: [
                GoogleMapsMarkerCardWidget(
                  quest: quest,
                  height: 96,
                  width: double.infinity,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),

            // Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
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
                  const SizedBox(height: 4),
                  Text(
                    '+${quest.xpReward} XP',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Daily Progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '1 / 3 completed',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
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
              minHeight: 7,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // Tasks List
          _buildDailyTaskItem(
            icon: Icons.location_on_rounded,
            title: 'Visit a new place',
            xp: '+50 XP',
            isCompleted: true,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _buildDailyTaskItem(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan 3 locations',
            xp: '+30 XP',
            isCompleted: false,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _buildDailyTaskItem(
            icon: Icons.camera_alt_rounded,
            title: 'Upload a photo',
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
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primaryLight : AppColors.surfaceElevated,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
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
          size: 24,
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
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

