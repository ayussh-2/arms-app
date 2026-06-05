import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_date_utils.dart';
import '../exam_edit_details_screen.dart';

class ExamConfigHeaderPanel extends StatelessWidget {
  final Map<String, dynamic> exam;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> schoolsLookup;
  final List<Map<String, dynamic>> classesLookup;
  final List<Map<String, dynamic>> sectionsLookup;
  final VoidCallback onExamDetailsUpdated;

  const ExamConfigHeaderPanel({
    super.key,
    required this.exam,
    required this.subjects,
    required this.schoolsLookup,
    required this.classesLookup,
    required this.sectionsLookup,
    required this.onExamDetailsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.stackMd, bottom: AppSpacing.stackLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('EXAM DETAILS', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExamEditDetailsScreen(
                              exam: exam,
                              subjects: subjects,
                              schoolsLookup: schoolsLookup,
                              classesLookup: classesLookup,
                              sectionsLookup: sectionsLookup,
                            ),
                          ),
                        );
                        if (result != null) {
                          exam['name'] = result['name'];
                          exam['chapter'] = result['chapter'];
                          exam['topic'] = result['topic'];
                          exam['exam_date'] = result['exam_date'];
                          exam['for_school'] = result['for_school'];
                          exam['for_class'] = result['for_class'];
                          exam['for_section'] = result['for_section'];
                          exam['total_marks'] = result['total_marks'];

                          final updatedMarks = result['subject_marks'] as Map<String, int>? ?? {};
                          for (final sub in subjects) {
                            final subId = sub['id'] as String;
                            if (updatedMarks.containsKey(subId)) {
                              sub['max_marks'] = updatedMarks[subId];
                            }
                          }
                          onExamDetailsUpdated();
                        }
                      },
                      child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Total: ${exam['total_marks'] ?? 0}',
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ConfigRow(label: 'SERIES', value: exam['series']?['name'] ?? 'N/A'),
                _ConfigRow(
                  label: 'DATE',
                  value: AppDateUtils.formatToDMY(DateTime.tryParse(exam['exam_date'] ?? '') ?? DateTime.now()),
                ),
                _ConfigRow(label: 'EXAM NAME', value: exam['name'] ?? ''),
                _ConfigRow(
                  label: 'SUBJECTS',
                  value: subjects.map((s) => s['name'] ?? '').join(', '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }
}
