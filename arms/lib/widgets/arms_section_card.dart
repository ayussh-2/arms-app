import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class ArmsSectionCard extends StatelessWidget {
  const ArmsSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 24),
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: AppTextStyles.headerSmall),
          ),
          const Divider(height: 1, color: AppColors.outlineLight),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
