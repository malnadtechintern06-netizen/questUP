import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/floating_particles_painter.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient 3D floating dust particles
          const Positioned.fill(
            child: FloatingParticlesWidget(
              numberOfParticles: 20,
              particleColor: AppColors.primary,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // 3D Glowing Emblem / Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF80F3FF),
                          AppColors.primary,
                          Color(0xFF0F1523),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          'assets/images/logo_emblem.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.explore_rounded,
                            size: 64,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App Name & Tagline
                  Text(
                    AppConstants.appName,
                    style: AppTypography.displayLarge.copyWith(
                      letterSpacing: 1.0,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Turn the Real World Into a Game',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),


                  // Adventure Feature Highlights (3D Glass Container)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderBright, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildFeatureRow(
                          icon: Icons.radar_rounded,
                          color: AppColors.primary,
                          title: 'Tactical GPS Radar',
                          description: 'Locate monuments, trails, and secrets in your area.',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Divider(color: AppColors.divider, height: 1),
                        ),
                        _buildFeatureRow(
                          icon: Icons.qr_code_scanner_rounded,
                          color: AppColors.accentXp,
                          title: 'Smart Proof Scanner',
                          description: 'Reach coordinates and capture verified photo proof.',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Divider(color: AppColors.divider, height: 1),
                        ),
                        _buildFeatureRow(
                          icon: Icons.military_tech_rounded,
                          color: AppColors.secondary,
                          title: 'Level Up & Claim Bounties',
                          description: 'Collect XP, coins, and climb the champions leaderboard.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3D Start Adventure Button
                  Premium3DButton(
                    text: 'GET STARTED',
                    icon: Icons.rocket_launch_rounded,
                    color: AppColors.primary,
                    width: double.infinity,
                    onPressed: () => context.go(RoutePaths.register),
                  ),
                  const SizedBox(height: 14),

                  // 3D Login Button
                  Premium3DButton(
                    text: 'I HAVE AN ACCOUNT - LOGIN',
                    icon: Icons.login_rounded,
                    isOutlined: true,
                    color: AppColors.primary,
                    textColor: AppColors.primary,
                    width: double.infinity,
                    onPressed: () => context.go(RoutePaths.login),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
