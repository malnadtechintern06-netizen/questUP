import 'package:flutter/material.dart';
import 'premium_3d_button.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;
  final bool isOutlined;
  final Color? customColor;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
    this.isOutlined = false,
    this.customColor,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Premium3DButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isSecondary: isSecondary,
      isOutlined: isOutlined,
      color: customColor,
      width: width,
      height: height,
      depth: 3.5,
    );
  }
}

