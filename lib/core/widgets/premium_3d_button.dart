import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class Premium3DButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;
  final bool isOutlined;
  final Color? color;
  final Color? textColor;
  final double? width;
  final double height;
  final double depth;

  const Premium3DButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
    this.isOutlined = false,
    this.color,
    this.textColor,
    this.width,
    this.height = 54,
    this.depth = 4.0,
  });


  @override
  State<Premium3DButton> createState() => _Premium3DButtonState();
}

class _Premium3DButtonState extends State<Premium3DButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (mounted) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = widget.color ??
        (widget.isSecondary ? AppColors.secondary : AppColors.primary);

    final isEnabled = widget.onPressed != null && !widget.isLoading;

    if (widget.isOutlined) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: OutlinedButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isEnabled ? primaryColor : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: _buildContent(primaryColor),
        ),
      );
    }

    final double currentDepth = _isPressed ? 1.0 : widget.depth;
    final double translateY = _isPressed ? widget.depth - 1.0 : 0.0;

    return GestureDetector(
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isEnabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor,
                    Color.lerp(primaryColor, Colors.black, 0.25) ?? primaryColor,
                  ],
                )
              : null,
          color: isEnabled ? null : (isDark ? AppColors.surfaceElevated : const Color(0xFFE2E8F0)),
          boxShadow: isEnabled
              ? [
                  // 3D Bottom Bevel / Depth Base
                  BoxShadow(
                    color: (Color.lerp(primaryColor, Colors.black, 0.6) ?? Colors.black)
                        .withValues(alpha: 0.9),
                    offset: Offset(0, currentDepth),
                    blurRadius: 0,
                  ),
                  // Glow Shadow
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    offset: Offset(0, currentDepth + 4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.3 : 0.05),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildContent(widget.textColor ?? (isEnabled ? Colors.black : (isDark ? AppColors.textMuted : const Color(0xFF94A3B8)))),
        ),
      ),
    );
  }


  Widget _buildContent(Color textColor) {
    if (widget.isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
