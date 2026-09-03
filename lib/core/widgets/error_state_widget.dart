import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'custom_button.dart';

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentDanger.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 44,
                  color: AppColors.accentDanger,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Exploration Interrupted',
              textAlign: TextAlign.center,
              style: AppTypography.displayMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'RETRY CONNECTION',
              icon: Icons.refresh_rounded,
              customColor: AppColors.primary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

