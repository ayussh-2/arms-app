import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'arms_button.dart';

/// A standardized confirmation alert dialog following the ARMS design.
/// Features clean typography, matching backgrounds, and consistent ArmsButton styling.
class ArmsConfirmDialog extends StatelessWidget {
  const ArmsConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.showCancel = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final bool showCancel;

  /// Helper to display this dialog and return true if confirmed, false if cancelled, or null.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    bool showCancel = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => ArmsConfirmDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            isDestructive: isDestructive,
            showCancel: showCancel,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Changed from 16
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        16,
      ), // Adjusted for better visual rhythm
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      title: Text(
        title,
        style: AppTextStyles.headerSmall.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textMain,
        ),
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      actions: [
        if (showCancel)
          ArmsButton(
            label: cancelLabel,
            variant: ArmsButtonVariant.text,
            size: ArmsButtonSize.medium,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ArmsButton(
          label: confirmLabel,
          variant:
              isDestructive
                  ? ArmsButtonVariant.destructive
                  : ArmsButtonVariant.primary,
          size: ArmsButtonSize.medium,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
