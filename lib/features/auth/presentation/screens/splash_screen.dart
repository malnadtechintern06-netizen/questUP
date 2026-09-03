import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/floating_particles_painter.dart';
import 'package:quest_up/features/auth/presentation/providers/auth_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  late AnimationController _sweepController;
  late Animation<double> _sweepAnimation;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Scale-in controller
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    // 2. Ambient glow pulse controller
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.95).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 3. Light sweep controller
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _sweepAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _sweepController, curve: Curves.easeInOut),
    );

    // 4. Text and UI fade controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start sequences
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _sweepController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fadeController.forward();
    });

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    final minimumDelay = Future.delayed(const Duration(milliseconds: 1600));
    final authCheck = ref.read(authNotifierProvider.notifier).checkInitialAuthState();
    final locationService = ref.read(locationServiceProvider);
    final locationCheck = locationService.isLocationEnabledAndPermitted();

    final results = await Future.wait([
      minimumDelay,
      authCheck,
      locationCheck,
    ]);

    if (!mounted) return;

    final authState = results[1] as AuthState;
    final isLocationReady = results[2] as bool;

    if (authState.isAuthenticated) {
      if (authState.user != null) {
        ref.read(userProfileNotifierProvider.notifier).updateProfile(
              id: authState.user!.id,
              name: authState.user!.displayName,
              email: authState.user!.email,
            );
      }

      if (isLocationReady) {
        // Pre-acquire GPS coordinates and initiate quest loading
        try {
          final coords = await locationService.getCurrentLocation();
          ref.read(activeGpsCoordinatesProvider.notifier).state = coords;
          unawaited(ref.read(questsNotifierProvider.notifier).fetchQuests(coords: coords, showLoading: false));
        } catch (_) {}

        if (mounted) {
          context.go(RoutePaths.home);
        }
      } else {
        context.go(RoutePaths.locationPermission);
      }
    } else {
      context.go(RoutePaths.welcome);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    _sweepController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FloatingParticlesWidget(
        particleCount: 25,
        color: AppColors.primary,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 3D Glowing Emblem with Light Sweep
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_glowAnimation, _sweepAnimation]),
                    builder: (context, _) {
                      return Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.2, -0.3),
                            radius: 0.9,
                            colors: [
                              Color(0xFF1E293B),
                              Color(0xFF0F172A),
                              Color(0xFF070B12),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: _glowAnimation.value * 0.8),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: _glowAnimation.value * 0.5),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: _glowAnimation.value * 0.25),
                              blurRadius: 50,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Inner 3D Logo Emblem
                              Padding(
                                padding: const EdgeInsets.all(22.0),
                                child: Image.asset(
                                  'assets/images/logo_emblem.png',
                                  width: 95,
                                  height: 95,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.explore_rounded,
                                    size: 70,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              // Light Sweep Shimmer Effect
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(_sweepAnimation.value * 150, 0),
                                  child: Transform.rotate(
                                    angle: 0.4,
                                    child: Container(
                                      width: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withValues(alpha: 0.45),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Title & Tagline with Fade Transition
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Color(0xFFFFFFFF),
                            Color(0xFFFFB800),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          AppConstants.appName.toUpperCase(),
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 34,
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          AppConstants.appTagline.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 52),

                // Subtle Progress Indicator
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

