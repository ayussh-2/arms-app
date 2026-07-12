import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'arms_input_field.dart';

/// A standardized date field wrapper around ArmsInputField.
/// Configures a read-only input showing a calendar icon and triggers date selection on tap.
class ArmsDateField extends StatelessWidget {
  const ArmsDateField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onTap,
    this.fillColor,
    this.hasBorder = false,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onTap;
  final Color? fillColor;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IgnorePointer(
        child: ArmsInputField(
          controller: controller,
          hintText: hintText,
          readOnly: true,
          fillColor: fillColor,
          hasBorder: hasBorder,
          suffixIcon: const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
