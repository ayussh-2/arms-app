import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ArmsSnackbar {
  /// Shows a success snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successText,
      ),
    );
  }

  /// Shows an error snackbar
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorText,
      ),
    );
  }

  /// Shows an info snackbar
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.onSurfaceVariant,
      ),
    );
  }

  /// Shows a warning snackbar
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFEF3C7),
      ),
    );
  }
}

