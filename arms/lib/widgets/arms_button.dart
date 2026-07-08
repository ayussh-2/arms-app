import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

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
        final fg = foregroundColor ?? AppColors.onPrimary;
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
            shape: const StadiumBorder(),
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );

      case ArmsButtonVariant.secondary:
        final fg = foregroundColor ?? AppColors.primary;
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg, width: 1.0),
            elevation: 0,
            minimumSize: minSize,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            shape: const StadiumBorder(),
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );

      case ArmsButtonVariant.destructive:
        // Red-on-secondary-shape (outlined style with red border and text)
        final fg = foregroundColor ?? AppColors.errorText;
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg, width: 1.5),
            elevation: 0,
            minimumSize: minSize,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            shape: const StadiumBorder(),
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );

      case ArmsButtonVariant.text:
        final fg = foregroundColor ?? AppColors.onSurfaceVariant;
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: fg,
            minimumSize: minSize,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: _buildChild(fg, spinnerSize, strokeWidth),
        );
    }
  }

  Widget _buildChild(Color fgColor, double spinnerSize, double strokeWidth) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: spinnerSize,
            height: spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
