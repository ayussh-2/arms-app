import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppStatusUtils {
  /// Returns a corresponding color based on attendance or exam status
  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
      case 'p':
      case 'published':
      case 'approved':
        return AppColors.primary;
      case 'absent':
      case 'a':
      case 'rejected':
      case 'fail':
        return AppColors.errorText;
      case 'late':
      case 'l':
      case 'draft':
      case 'pending':
        return Colors.orange;
      case 'half-day':
      case 'hd':
        return Colors.blue;
      default:
        return AppColors.onSurfaceVariant;
    }
  }
}
