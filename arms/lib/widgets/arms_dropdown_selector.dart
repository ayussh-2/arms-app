import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_radius.dart';

/// Pill-shaped dropdown selector matching the attendance-configuration design.
/// Displays a label, current value, and a trailing chevron icon.
class ArmsDropdownSelector extends StatelessWidget {
  const ArmsDropdownSelector({
    super.key,
    this.label,
    required this.value,
    this.placeholder,
    required this.onTap,
    this.icon,
  });

  final String? label;
  final String? value;
  final String? placeholder;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              label!,
              style: AppTextStyles.labelXs.copyWith(
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.textSecondary, size: 22),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    hasValue ? value! : (placeholder ?? 'Select'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color:
                          hasValue
                              ? AppColors.textMain
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
