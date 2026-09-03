import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/floating_particles_painter.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';
import 'package:quest_up/features/location_permission/presentation/providers/location_permission_provider.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationPermissionNotifierProvider.notifier).checkInitialState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationPermissionNotifierProvider.notifier).checkAndAutoResume().then((isReady) {
        if (isReady && mounted) {
          context.go(RoutePaths.home);
        }
      });
    }
  }

  void _navigateToHome() {
    if (mounted) {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for completion to automatically transition to Home
    ref.listen<LocationPermissionState>(locationPermissionNotifierProvider, (previous, next) {
      if (next.isReady) {
        _navigateToHome();
      }
    });

    final state = ref.watch(locationPermissionNotifierProvider);
    final notifier = ref.read(locationPermissionNotifierProvider.notifier);

    // Dynamic icon and color based on state
    IconData headerIcon = Icons.location_on_rounded;
    Color headerColor = AppColors.primary;
    String headerTitle = '📍 Enable Location';
    String headerSubtitle = 'QuestUP uses your physical position to find nearby real-world quests and verify landmark arrival.';

    if (state.status == LocationPermissionUIState.gpsDisabled) {
      headerIcon = Icons.location_searching_rounded;
      headerColor = AppColors.secondary;
      headerTitle = '🛰️ Location Services Disabled';
      headerSubtitle = 'Location hardware is off on your device. Please turn on GPS in your Android settings.';
    } else if (state.status == LocationPermissionUIState.permissionDeniedForever) {
      headerIcon = Icons.location_off_rounded;
      headerColor = AppColors.accentDanger;
      headerTitle = '📍 Permission Required';
      headerSubtitle = 'Location permission is permanently denied. Please enable it in QuestUP App Settings.';
    } else if (state.status == LocationPermissionUIState.permissionDenied) {
      headerIcon = Icons.location_on_outlined;
      headerColor = AppColors.primary;
      headerTitle = '📍 Enable Location';
      headerSubtitle = 'QuestUP needs location permission to detect nearby landmarks and verify your adventures.';
    } else if (state.status == LocationPermissionUIState.locationReady) {
      headerIcon = Icons.check_circle_rounded;
      headerColor = AppColors.accentSuccess;
      headerTitle = '📍 GPS Signal Locked';
      headerSubtitle = 'Your real-world GPS position has been verified. You are ready to explore!';
    }


    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: FloatingParticlesWidget(
              numberOfParticles: 16,
              particleColor: AppColors.primary,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 1),

                          // Animated Glowing Radar / GPS 3D Emblem
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(color: headerColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: headerColor.withValues(alpha: 0.4),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                headerIcon,
                                color: headerColor,
                                size: 54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Heading
                          Text(
                            headerTitle,
                            style: AppTypography.displayMedium.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),

                          // Description
                          Text(
                            headerSubtitle,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Live Status / Coordinates Card or Alert Card
                          if (state.coordinates != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.accentSuccess, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentSuccess.withValues(alpha: 0.15),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: AppColors.accentSuccess, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'GPS Telemetry Locked',
                                        style: AppTypography.titleMedium.copyWith(
                                          color: AppColors.accentSuccess,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Latitude: ${state.coordinates!.latitude.toStringAsFixed(4)}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Longitude: ${state.coordinates!.longitude.toStringAsFixed(4)}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (state.coordinates!.accuracy != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Accuracy: ±${state.coordinates!.accuracy!.toStringAsFixed(1)}m',
                                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else if (state.message != null &&
                              state.status != LocationPermissionUIState.initial) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: state.isLoading
                                    ? AppColors.surfaceElevated
                                    : (state.status == LocationPermissionUIState.gpsDisabled
                                        ? AppColors.secondary.withValues(alpha: 0.12)
                                        : AppColors.accentDanger.withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: state.isLoading
                                      ? AppColors.border
                                      : (state.status == LocationPermissionUIState.gpsDisabled
                                          ? AppColors.secondary.withValues(alpha: 0.5)
                                          : AppColors.accentDanger.withValues(alpha: 0.5)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (state.isLoading)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      ),
                                    )
                                  else
                                    Icon(
                                      state.status == LocationPermissionUIState.gpsDisabled
                                          ? Icons.location_searching_rounded
                                          : Icons.info_outline_rounded,
                                      color: state.status == LocationPermissionUIState.gpsDisabled
                                          ? AppColors.secondary
                                          : AppColors.accentDanger,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      state.message!,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: state.isLoading
                                            ? AppColors.textPrimary
                                            : (state.status == LocationPermissionUIState.gpsDisabled
                                                ? AppColors.textPrimary
                                                : AppColors.accentDanger),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          const Spacer(flex: 2),

                          // Contextual 3D Primary Action Button
                          if (state.status == LocationPermissionUIState.gpsDisabled) ...[
                            Premium3DButton(
                              text: 'ENABLE GPS IN SETTINGS',
                              icon: Icons.location_searching_rounded,
                              color: AppColors.secondary,
                              width: double.infinity,
                              onPressed: () => notifier.openLocationSettings(),
                            ),
                          ] else if (state.status == LocationPermissionUIState.permissionDeniedForever) ...[
                            Premium3DButton(
                              text: 'OPEN APP SETTINGS',
                              icon: Icons.settings_rounded,
                              color: AppColors.accentDanger,
                              width: double.infinity,
                              onPressed: () => notifier.openAppSettings(),
                            ),
                          ] else if (state.status == LocationPermissionUIState.error) ...[
                            Premium3DButton(
                              text: 'RETRY CONNECTION',
                              icon: Icons.refresh_rounded,
                              color: AppColors.primary,
                              isLoading: state.isLoading,
                              width: double.infinity,
                              onPressed: () => notifier.requestAndAcquireLocation(),
                            ),
                          ] else ...[
                            Premium3DButton(
                              text: state.coordinates != null ? 'CONTINUE TO RADAR' : 'ALLOW LOCATION',
                              icon: state.coordinates != null
                                  ? Icons.check_circle_rounded
                                  : Icons.my_location_rounded,
                              color: AppColors.primary,
                              isLoading: state.isLoading,
                              width: double.infinity,
                              onPressed: () async {
                                if (state.coordinates != null) {
                                  _navigateToHome();
                                } else {
                                  final success = await notifier.requestAndAcquireLocation();
                                  if (success) {
                                    _navigateToHome();
                                  }
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Maybe Later button
                          TextButton(
                            onPressed: () async {
                              await notifier.skipForNow();
                              _navigateToHome();
                            },
                            child: Text(
                              'Maybe Later',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
