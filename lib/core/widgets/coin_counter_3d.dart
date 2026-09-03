import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class CoinCounter3D extends StatelessWidget {
  final int coins;
  final double size;
  final bool showLabel;
  final VoidCallback? onTap;

  const CoinCounter3D({
    super.key,
    required this.coins,
    this.size = 20,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3D Coin Graphic
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  radius: 0.8,
                  colors: [
                    Color(0xFFFFE082),
                    Color(0xFFFFB800),
                    Color(0xFFE65100),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.6),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
              ),
              child: const Center(
                child: Text(
                  '🪙',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Animated Rollup for coins
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: coins.toDouble()),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuad,
              builder: (context, value, _) {
                return Text(
                  value.toInt().toString(),
                  style: AppTypography.gameNumber.copyWith(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
            if (showLabel) ...[
              const SizedBox(width: 3),
              Text(
                'COINS',
                style: AppTypography.badge.copyWith(
                  color: AppColors.secondary.withValues(alpha: 0.8),
                  fontSize: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
