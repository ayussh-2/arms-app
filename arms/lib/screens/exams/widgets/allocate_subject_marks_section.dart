import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AllocateSubjectMarksSection extends StatelessWidget {
  final List<Map<String, dynamic>> subjects;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onCalculatedTotalChanged;

  const AllocateSubjectMarksSection({
    super.key,
    required this.subjects,
    required this.controllers,
    required this.onCalculatedTotalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: subjects.map((sub) {
          final subId = sub['id'] as String;
          final controller = controllers[subId]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    sub['name'] ?? '',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Max Marks',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      onChanged: (val) {
                        onCalculatedTotalChanged();
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
