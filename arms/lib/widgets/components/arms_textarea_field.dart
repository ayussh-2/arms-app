import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

/// A standard, rectangular text area field for longer text inputs.
/// Conforms to the design system with roundTwelve radius, cardSurface fill by default.
class ArmsTextAreaField extends StatelessWidget {
  const ArmsTextAreaField({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 4,
    this.validator,
    this.onChanged,
    this.fillColor = AppColors.cardSurface,
    this.hasBorder = true,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final Color fillColor;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.labelXs.copyWith(
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
          borderSide: hasBorder
              ? const BorderSide(color: AppColors.outlineLight, width: 1.0)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
          borderSide: hasBorder
              ? const BorderSide(color: AppColors.outlineLight, width: 1.0)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
