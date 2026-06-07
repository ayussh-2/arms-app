import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class HeaderMeta extends StatelessWidget {
  const HeaderMeta({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelXsUppercase.copyWith(
              fontSize: 10,
              letterSpacing: 1,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.labelXs.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class ActionChipWidget extends StatelessWidget {
  const ActionChipWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.textMain;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(9999),
          border: filled
              ? null
              : Border.all(
                  color: color?.withValues(alpha: 0.2) ?? AppColors.outlineLight,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? AppColors.onPrimary : activeColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelXs.copyWith(
                color: filled ? AppColors.onPrimary : activeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaginationButton extends StatelessWidget {
  const PaginationButton({
    super.key,
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEnabled ? AppColors.primary : AppColors.cardSurface,
            shape: BoxShape.circle,
            border: isEnabled ? null : Border.all(color: AppColors.outlineLight),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isEnabled ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
