import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography tokens matching the "Clean Utility" design spec.
/// Uses Google Fonts for Plus Jakarta Sans to avoid bundling font files.
class AppTextStyles {
  AppTextStyles._();

  static final TextStyle displayLarge = GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.28,
        color: AppColors.textMain,
      );

  static final TextStyle displayMobile = GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.12,
        color: AppColors.textMain,
      );

  static final TextStyle headerSmall = GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.18,
        color: AppColors.textMain,
      );

  static final TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textMain,
      );

  static final TextStyle labelXs = GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static final TextStyle labelXsUppercase = GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.textSecondary,
      );
}
