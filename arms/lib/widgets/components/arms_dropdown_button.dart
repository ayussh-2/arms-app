import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A standard, bordered dropdown button wrapper matching the ARMS design specification.
/// Provides a consistent 12px border radius, white background, and custom border color.
class ArmsDropdownButton<T> extends StatelessWidget {
  const ArmsDropdownButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.items,
    this.isExpanded = true,
  });

  final T? value;
  final ValueChanged<T?>? onChanged;
  final List<DropdownMenuItem<T>> items;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: isExpanded,
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}
