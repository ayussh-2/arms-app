import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';

/// Dashboard feature card matching the dashboard.html design.
/// Shows icon in coloured circle, title, description. Full-width tappable.
class ArmsDashboardButton extends StatelessWidget {
  const ArmsDashboardButton({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.iconBgColor,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color? iconBgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = iconBgColor ?? AppColors.accent;

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppSpacing.stackMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.stackMd),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: bgColor, size: 32),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              // Title
              Text(
                title,
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              // Description
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
