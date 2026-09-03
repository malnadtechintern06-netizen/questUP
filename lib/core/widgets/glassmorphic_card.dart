import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final double elevation;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Gradient? gradient;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.glowColor,
    this.borderColor,
    this.backgroundColor,
    this.elevation = 4.0,
    this.onTap,
    this.width,
    this.height,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorder = borderColor ??
        (glowColor != null
            ? glowColor!.withValues(alpha: 0.4)
            : (isDark ? AppColors.border : const Color(0xFFE2E8F0)));

    final defaultBg = backgroundColor ??
        (isDark ? AppColors.surface : AppColors.lightSurface);

    final defaultGradient = gradient ??
        (isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceElevated.withValues(alpha: 0.8),
                  AppColors.surface.withValues(alpha: 0.95),
                ],
              )
            : null);

    final cardWidget = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: defaultBg,
        gradient: defaultGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: defaultBorder, width: glowColor != null ? 1.5 : 1.0),
        boxShadow: [
          // Depth shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: elevation * 4,
            offset: Offset(0, elevation * 1.5),
          ),
          // Ambient neon glow (if specified)
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.2),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
