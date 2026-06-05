import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ExamFiltersPanel extends StatelessWidget {
  final String? selectedSeries;
  final String? selectedSubject;
  final String? selectedSchool;
  final String? selectedClass;
  final String? selectedSection;
  final List<String> seriesOptions;
  final List<String> subjectOptions;
  final List<String> schoolOptions;
  final List<String> classOptions;
  final List<String> sectionOptions;
  final ValueChanged<String?> onSeriesSelected;
  final ValueChanged<String?> onSubjectSelected;
  final ValueChanged<String?> onSchoolSelected;
  final ValueChanged<String?> onClassSelected;
  final ValueChanged<String?> onSectionSelected;
  final VoidCallback onClearFilters;

  const ExamFiltersPanel({
    super.key,
    required this.selectedSeries,
    required this.selectedSubject,
    required this.selectedSchool,
    required this.selectedClass,
    required this.selectedSection,
    required this.seriesOptions,
    required this.subjectOptions,
    required this.schoolOptions,
    required this.classOptions,
    required this.sectionOptions,
    required this.onSeriesSelected,
    required this.onSubjectSelected,
    required this.onSchoolSelected,
    required this.onClassSelected,
    required this.onSectionSelected,
    required this.onClearFilters,
  });

  Widget _buildFilterPill({
    required BuildContext context,
    required String label,
    required String? selectedValue,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    final isSelected = selectedValue != null;
    return GestureDetector(
      onTap: () async {
        final chosen = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text('Select $label'),
            children: options
                .map((e) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, e),
                      child: Text(e),
                    ))
                .toList(),
          ),
        );
        onSelected(chosen);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineMediumLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSelected ? '$label: $selectedValue' : label,
              style: AppTextStyles.labelXs.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.textMain,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more,
                size: 16,
                color: isSelected ? AppColors.onPrimary : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyFilter = selectedSeries != null ||
        selectedSubject != null ||
        selectedSchool != null ||
        selectedClass != null ||
        selectedSection != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterPill(
            context: context,
            label: 'Series',
            selectedValue: selectedSeries,
            options: seriesOptions,
            onSelected: onSeriesSelected,
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            context: context,
            label: 'Subjects',
            selectedValue: selectedSubject,
            options: subjectOptions,
            onSelected: onSubjectSelected,
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            context: context,
            label: 'Schools',
            selectedValue: selectedSchool,
            options: schoolOptions,
            onSelected: onSchoolSelected,
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            context: context,
            label: 'Classes',
            selectedValue: selectedClass,
            options: classOptions,
            onSelected: onClassSelected,
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            context: context,
            label: 'Sections',
            selectedValue: selectedSection,
            options: sectionOptions,
            onSelected: onSectionSelected,
          ),
          if (hasAnyFilter) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onClearFilters,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Clear',
                  style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
