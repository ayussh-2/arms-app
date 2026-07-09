import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum ArmsStatusType {
  success,
  error,
  warning,
  neutral,
}

/// A standardized status badge/chip matching the ARMS design specification.
/// Displays semantic statuses (success, error, warning, neutral) with consistent padding and fonts.
class ArmsStatusBadge extends StatelessWidget {
  const ArmsStatusBadge({
    super.key,
    required this.label,
    this.type = ArmsStatusType.neutral,
    this.fontSize = 10.0,
  });

  final String label;
  final ArmsStatusType type;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case ArmsStatusType.success:
        bg = AppColors.successBg;
        fg = AppColors.successText;
        break;
      case ArmsStatusType.error:
        bg = AppColors.errorBg;
        fg = AppColors.errorText;
        break;
      case ArmsStatusType.warning:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF78350F);
        break;
      case ArmsStatusType.neutral:
        bg = AppColors.surfaceVariant;
        fg = AppColors.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelXsUppercase.copyWith(
          color: fg,
          fontSize: fontSize,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
