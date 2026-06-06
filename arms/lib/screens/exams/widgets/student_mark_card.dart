import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class StudentMarkCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final int slNo;
  final ValueNotifier<bool> absentNotifier;
  final ValueNotifier<String> statusNotifier;
  final Map<String, TextEditingController> controllers;
  final List<Map<String, dynamic>> subjects;
  final bool isEditing;
  final List<FocusNode>? focusNodes;
  final double itemWidth;
  final VoidCallback onAbsentToggled;
  final VoidCallback onStatusChanged;
  final void Function(String subjectId, String val) onMarkChanged;
  final VoidCallback? onNext;

  const StudentMarkCard({
    super.key,
    required this.student,
    required this.slNo,
    required this.absentNotifier,
    required this.statusNotifier,
    required this.controllers,
    required this.subjects,
    required this.isEditing,
    this.focusNodes,
    required this.itemWidth,
    required this.onAbsentToggled,
    required this.onStatusChanged,
    required this.onMarkChanged,
    this.onNext,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'RNFP':
        return AppColors.accent;
      case 'MLP':
        return AppColors.errorText;
      default:
        return AppColors.surfaceContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: absentNotifier,
      builder: (context, isAbsent, _) {
        return ValueListenableBuilder<String>(
          valueListenable: statusNotifier,
          builder: (context, status, __) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$slNo. ${student['name'] ?? ''}',
                              style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Roll No: ${student['roll_no'] ?? ''}',
                              style: AppTextStyles.labelXs.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: onAbsentToggled,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAbsent ? AppColors.errorText : AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: isAbsent ? AppColors.errorText : AppColors.outlineLight,
                                ),
                              ),
                              child: Text(
                                isAbsent ? 'ABSENT' : 'MARK ABSENT',
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: isAbsent ? Colors.white : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: onStatusChanged,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                status == 'MLP' ? 'MALPRACTICE' : status,
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: status == 'NORMAL' ? AppColors.onSurfaceVariant : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: subjects.asMap().entries.map((entry) {
                      final subjectIndex = entry.key;
                      final es = entry.value;
                      final subjectId = es['id'] as String? ?? '';
                      final subjectName = es['name'] as String? ?? '';
                      final maxMarks = es['max_marks'] as num? ?? 100;
                      final controller = controllers[subjectId];

                      FocusNode? markFieldFocusNode;
                      if (isEditing && focusNodes != null) {
                        if (subjectIndex < focusNodes!.length) {
                          markFieldFocusNode = focusNodes![subjectIndex];
                        }
                      }

                      return SizedBox(
                        width: itemWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                subjectName.toUpperCase(),
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (controller != null)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: controller,
                                builder: (context, value, _) {
                                  final currentVal = double.tryParse(value.text);
                                  final isError = currentVal != null && currentVal > maxMarks.toDouble();
                                  return TextFormField(
                                    focusNode: markFieldFocusNode,
                                    controller: controller,
                                    onChanged: (val) => onMarkChanged(subjectId, val),
                                    enabled: !isAbsent,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => onNext?.call(),
                                    decoration: InputDecoration(
                                      hintText: '00',
                                      hintStyle: AppTextStyles.headerSmall.copyWith(color: AppColors.outline.withValues(alpha: 0.5)),
                                      filled: true,
                                      fillColor: isAbsent ? AppColors.surfaceVariant.withValues(alpha: 0.3) : Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      errorText: isError ? 'Max: $maxMarks' : null,
                                      errorStyle: AppTextStyles.labelXs.copyWith(color: AppColors.errorText, fontSize: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.outlineLight),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.outlineLight),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
