import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/arms_input_field.dart';
import '../../../widgets/arms_dropdown_selector.dart';

class ExamCreateGeneralInfo extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController chapterController;
  final TextEditingController topicController;
  final TextEditingController dateController;
  final TextEditingController marksController;
  final VoidCallback selectDate;
  final VoidCallback showSeriesSelector;
  final String? selectedSeriesName;
  final VoidCallback showSubjectSelectSheet;
  final List<Map<String, dynamic>> selectedSubjects;
  final Map<String, TextEditingController> subjectControllers;
  final ValueChanged<Map<String, dynamic>> onSubjectRemoved;
  final VoidCallback onSubjectMarkChanged;

  const ExamCreateGeneralInfo({
    super.key,
    required this.nameController,
    required this.chapterController,
    required this.topicController,
    required this.dateController,
    required this.marksController,
    required this.selectDate,
    required this.showSeriesSelector,
    required this.selectedSeriesName,
    required this.showSubjectSelectSheet,
    required this.selectedSubjects,
    required this.subjectControllers,
    required this.onSubjectRemoved,
    required this.onSubjectMarkChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'General Information',
          style: AppTextStyles.headerSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 16),
        // Series selector
        ArmsDropdownSelector(
          label: 'Select Exam Series',
          value: selectedSeriesName,
          placeholder: 'Select Exam Series',
          onTap: showSeriesSelector,
        ),
        const SizedBox(height: 16),
        // Subjects chips
        _Label(text: 'Select Subjects'),
        GestureDetector(
          onTap: showSubjectSelectSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.roundEight),
              border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedSubjects.isEmpty
                        ? 'Search and select subjects...'
                        : 'Selected (${selectedSubjects.length} subjects)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: selectedSubjects.isEmpty ? AppColors.textSecondary : AppColors.textMain,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        // Subject chips list
        if (selectedSubjects.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedSubjects.map((sub) {
              final name = sub['name'] as String? ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.roundFull),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: AppTextStyles.labelXs.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onSubjectRemoved(sub),
                      child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Allocate Subject Marks',
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: selectedSubjects.map((sub) {
                final subId = sub['id'] as String;
                final ctrl = subjectControllers[subId]!;
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
                            controller: ctrl,
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
                            onChanged: (_) => onSubjectMarkChanged(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Exam name, chapter, topic, date, total marks
        _Label(text: 'Exam Name'),
        ArmsInputField(controller: nameController, hintText: 'e.g., Mathematics Advanced Quiz'),
        const SizedBox(height: 16),
        _Label(text: 'Chapter'),
        ArmsInputField(controller: chapterController, hintText: 'e.g., Chapter 04'),
        const SizedBox(height: 16),
        _Label(text: 'Topic'),
        ArmsInputField(controller: topicController, hintText: 'e.g., Calculus'),
        const SizedBox(height: 16),
        _Label(text: 'Exam Date'),
        GestureDetector(
          onTap: selectDate,
          child: AbsorbPointer(
            child: ArmsInputField(
              controller: dateController,
              hintText: 'YYYY-MM-DD',
              prefixIcon: Icons.calendar_today,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Label(text: 'Total Marks'),
        AbsorbPointer(
          child: ArmsInputField(
            controller: marksController,
            hintText: 'Total Marks (Auto-calculated)',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppTextStyles.labelXs.copyWith(color: AppColors.textMain, fontWeight: FontWeight.w700)),
  );
}
