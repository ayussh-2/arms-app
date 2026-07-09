import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum ArmsButtonVariant {
  primary,
  secondary,
  text,
  destructive,
}

enum ArmsButtonSize {
  small,
  medium,
  large,
}

/// A standard, reusable button component matching the ARMS design specification.
/// Support primary, secondary, text, and destructive variants, as well as size adjustments,
/// loading states, and leading icons.
class ArmsButton extends StatelessWidget {
  const ArmsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ArmsButtonVariant.primary,
    this.size = ArmsButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ArmsButtonVariant variant;
  final ArmsButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final double buttonHeight;
    final double horizontalPadding;
    final double spinnerSize;
    final double strokeWidth;

    switch (size) {
      case ArmsButtonSize.large:
        buttonHeight = 52.0;
        horizontalPadding = 24.0;
        spinnerSize = 20.0;
        strokeWidth = 2.5;
        break;
      case ArmsButtonSize.medium:
        buttonHeight = 44.0;
        horizontalPadding = 16.0;
        spinnerSize = 18.0;
        strokeWidth = 2.0;
        break;
      case ArmsButtonSize.small:
        buttonHeight = 36.0;
        horizontalPadding = 12.0;
        spinnerSize = 16.0;
        strokeWidth = 2.0;
        break;
    }

    final buttonWidth = fullWidth ? double.infinity : 0.0;
    final minSize = Size(buttonWidth, buttonHeight);

    // Resolve Colors & Style based on Variant
    switch (variant) {
      case ArmsButtonVariant.primary:
        final bg = backgroundColor ?? AppColors.primary;
        final fg = foregroundColor ?? Colors.white;
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.6),
            disabledForegroundColor: fg.withValues(alpha: 0.6),
            elevation: 0,
            minimumSize: minSize,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );

      case ArmsButtonVariant.secondary:
        final fg = foregroundColor ?? AppColors.primary;
        final secondaryBg = backgroundColor ?? Colors.transparent;
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: secondaryBg,
            foregroundColor: fg,
            disabledForegroundColor: fg.withValues(alpha: 0.6),
            disabledBackgroundColor: secondaryBg == Colors.transparent
                ? Colors.transparent
                : secondaryBg.withValues(alpha: 0.6),
            side: BorderSide(color: fg, width: 1.0),
            elevation: 0,
            minimumSize: minSize,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );

      case ArmsButtonVariant.destructive:
        final fg = foregroundColor ?? AppColors.errorText;
        final destructiveBg = backgroundColor ?? Colors.transparent;
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: destructiveBg,
            foregroundColor: fg,
            disabledForegroundColor: fg.withValues(alpha: 0.6),
            disabledBackgroundColor: destructiveBg == Colors.transparent
                ? Colors.transparent
                : destructiveBg.withValues(alpha: 0.6),
            side: BorderSide(color: fg, width: 1.0),
            elevation: 0,
            minimumSize: minSize,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );

      case ArmsButtonVariant.text:
        final fg = foregroundColor ?? AppColors.onSurfaceVariant;
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            backgroundColor: backgroundColor ?? Colors.transparent,
            foregroundColor: fg,
            disabledForegroundColor: fg.withValues(alpha: 0.6),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );
    }
  }

  Widget _buildChild(Color fgColor, double spinnerSize, double strokeWidth) {
    if (isLoading) {
      return SizedBox(
        width: spinnerSize,
        height: spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(fgColor),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: fgColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}