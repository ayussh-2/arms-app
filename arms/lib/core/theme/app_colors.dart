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
  static const Color outlineLight = Color(0x26C4C7C7);       // 0.15 opacity
  static const Color outlineMediumLight = Color(0x4DC4C7C7); // 0.3 opacity
  static const Color outlineFaint = Color(0x14C4C7C7);       // 0.08 opacity
  
  // Opacity variants for other colors
  static const Color primaryLight = Color(0x1A0051D5);       // 0.1 opacity
  static const Color primaryFaint = Color(0x0C0051D5);       // 0.05 opacity
  static const Color accentLight = Color(0x1A2563EB);        // 0.1 opacity

  // Semantic — Success
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF16A34A);

  // Semantic — Error
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color errorText = Color(0xFFDC2626);

  // Accent (used in icon tints on dashboard)
  static const Color accent = Color(0xFF2563EB);
}
