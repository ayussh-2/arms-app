import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Pill-shaped input field used for login forms and search bars.
/// Matches the HTML design: full-pill shape, filled bg, icon prefix,
/// focus ring in primary blue. Supports custom borders and fills.
class ArmsInputField extends StatelessWidget {
  const ArmsInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.textStyle,
    this.fillColor,
    this.hasBorder = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;
  final Color? fillColor;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: focusNode,
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: textStyle ?? AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.outlineMedium,
        ),
        filled: true,
        fillColor: fillColor ?? AppColors.surfaceVariant,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.outlineMedium, size: 22)
            : null,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: hasBorder
              ? const BorderSide(color: AppColors.outlineLight, width: 1.0)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: hasBorder
              ? const BorderSide(color: AppColors.outlineLight, width: 1.0)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
