import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/custom_button.dart';
import 'package:quest_up/features/location_permission/presentation/providers/location_permission_provider.dart';

class LocationPermissionScreen extends ConsumerWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationPermissionNotifierProvider);
    final notifier = ref.read(locationPermissionNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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

                      // Animated Glowing Radar / GPS Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.accentLocation, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentLocation.withValues(alpha: 0.35),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.location_on_rounded,
                            color: AppColors.accentLocation,
                            size: 52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Heading
                      Text(
                        '📍 Enable Location',
                        style: AppTypography.displayMedium.copyWith(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        'QuestUP uses your location to find nearby real-world quests and verify that you have reached quest locations.',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Live Status / Coordinates Card
                      if (state.coordinates != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
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
                                    'GPS Signal Locked',
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
                      ] else if (state.message != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: state.status == LocationPermissionUIState.requesting
                                ? AppColors.surfaceElevated
                                : AppColors.accentDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: state.status == LocationPermissionUIState.requesting
                                  ? AppColors.border
                                  : AppColors.accentDanger.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (state.status == LocationPermissionUIState.requesting)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentLocation),
                                  ),
                                )
                              else
                                const Icon(Icons.info_outline_rounded,
                                    color: AppColors.accentDanger, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  state.message!,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: state.status == LocationPermissionUIState.requesting
                                        ? AppColors.textPrimary
                                        : AppColors.accentDanger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Settings Helper Buttons if permission denied or GPS disabled
                      if (state.status == LocationPermissionUIState.permanentlyDenied) ...[
                        CustomButton(
                          text: 'OPEN APP SETTINGS',
                          icon: Icons.settings_rounded,
                          isOutlined: true,
                          width: double.infinity,
                          onPressed: () => notifier.openAppSettings(),
                        ),
                        const SizedBox(height: 12),
                      ] else if (state.status == LocationPermissionUIState.serviceDisabled) ...[
                        CustomButton(
                          text: 'ENABLE GPS IN SETTINGS',
                          icon: Icons.location_searching_rounded,
                          isOutlined: true,
                          width: double.infinity,
                          onPressed: () => notifier.openLocationSettings(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const Spacer(flex: 2),

                      // Action CTA: Allow Location / Continue
                      CustomButton(
                        text: state.coordinates != null ? 'CONTINUE TO QUESTS' : 'ALLOW LOCATION',
                        icon: state.coordinates != null
                            ? Icons.check_circle_outline_rounded
                            : Icons.my_location_rounded,
                        customColor: AppColors.primary,
                        isLoading: state.status == LocationPermissionUIState.requesting,
                        width: double.infinity,
                        onPressed: () async {
                          if (state.coordinates != null) {
                            context.go(RoutePaths.home);
                          } else {
                            final success = await notifier.requestAndAcquireLocation();
                            if (success && context.mounted) {
                              await Future.delayed(const Duration(milliseconds: 600));
                              if (context.mounted) {
                                context.go(RoutePaths.home);
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Maybe Later button
                      TextButton(
                        onPressed: () async {
                          await notifier.skipForNow();
                          if (context.mounted) {
                            context.go(RoutePaths.home);
                          }
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
    );
  }
}
