import 'package:flutter/material.dart';

/// Central color palette for the ARMS app.
/// Mapped from the "Clean Utility" design specification.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0051D5);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardSurface = Color(0xFFF5F5F5);
  static const Color surfaceVariant = Color(0xFFE5E2E1);
  static const Color surfaceContainer = Color(0xFFF1EDEC);

  // Text
  static const Color textMain = Color(0xFF0D0D0D);
  static const Color textSecondary = Color(0xFF8A8A8A);
  static const Color onSurfaceVariant = Color(0xFF444748);

  // Outlines
  static const Color outline = Color(0xFFC4C7C7);
  static const Color outlineMedium = Color(0xFF747878);

  // Semantic — Success
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF16A34A);

  // Semantic — Error
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color errorText = Color(0xFFDC2626);

  // Accent (used in icon tints on dashboard)
  static const Color accent = Color(0xFF2563EB);
}
