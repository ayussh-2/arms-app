import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';

/// Bottom-docked footer with summary stats and action buttons.
/// Uses backdrop blur for translucency. Matches attendance-sheet.html footer.
class ArmsStickyFooter extends StatelessWidget {
  const ArmsStickyFooter({
    super.key,
    this.summaryWidget,
    required this.primaryButtonText,
    this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
  });

  final Widget? summaryWidget;
  final String primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPrimaryPressed != null;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginPage,
            AppSpacing.stackMd,
            AppSpacing.marginPage,
            MediaQuery.of(context).padding.bottom + AppSpacing.stackMd,
          ),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            border: const Border(
              top: BorderSide(color: AppColors.surfaceVariant, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summaryWidget != null) ...[
                summaryWidget!,
                const SizedBox(height: AppSpacing.stackMd),
              ],
              if (secondaryButtonText != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onSecondaryPressed,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.outlineMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Text(
                      secondaryButtonText!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onPrimaryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled ? AppColors.primary : AppColors.cardSurface,
                    foregroundColor: isEnabled ? AppColors.onPrimary : AppColors.textSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: Text(
                    primaryButtonText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isEnabled ? AppColors.onPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
