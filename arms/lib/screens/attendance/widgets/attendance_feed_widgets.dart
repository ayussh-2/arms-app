import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';

class SummaryItem extends StatelessWidget {
  const SummaryItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelXsUppercase),
        Text(value, style: AppTextStyles.headerSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class BulkButton extends StatelessWidget {
  const BulkButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: onTap != null
              ? AppColors.outline.withValues(alpha: 0.5)
              : AppColors.outline.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelXs.copyWith(
              fontWeight: FontWeight.w600,
              color: onTap != null ? AppColors.onSurfaceVariant : AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
