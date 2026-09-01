import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/custom_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Logo & Glow Emblem
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    width: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.explore_rounded, size: 72, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // App Name & Tagline
              Text(
                AppConstants.appName,
                style: AppTypography.displayLarge.copyWith(
                  letterSpacing: 0.5,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.appTagline,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // Adventure Feature Highlights
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B2433),
                      AppColors.surface,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      icon: Icons.radar_rounded,
                      color: AppColors.accentLocation,
                      title: 'Discover Nearby Quests',
                      description: 'Locate monuments, trails, and secrets in your area.',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Divider(color: AppColors.divider, height: 1),
                    ),
                    _buildFeatureRow(
                      icon: Icons.photo_camera_rounded,
                      color: AppColors.primary,
                      title: 'GPS & Camera Proof',
                      description: 'Reach coordinates and snap proof to verify completions.',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Divider(color: AppColors.divider, height: 1),
                    ),
                    _buildFeatureRow(
                      icon: Icons.military_tech_rounded,
                      color: AppColors.secondary,
                      title: 'Level Up & Earn Rewards',
                      description: 'Collect XP, coins, and climb the champions leaderboard.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // CTA Action Buttons
              CustomButton(
                text: 'GET STARTED',
                icon: Icons.arrow_forward_rounded,
                width: double.infinity,
                onPressed: () {
                  context.push(RoutePaths.register);
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'I HAVE AN ACCOUNT - LOGIN',
                isOutlined: true,
                width: double.infinity,
                onPressed: () {
                  context.push(RoutePaths.login);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
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
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
