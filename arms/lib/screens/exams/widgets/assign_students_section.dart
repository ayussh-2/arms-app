import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/arms_dropdown_selector.dart';
import 'exam_selection_sheets.dart';

class AssignStudentsSection extends StatelessWidget {
  final List<Map<String, dynamic>> schoolsLookup;
  final List<Map<String, dynamic>> classesLookup;
  final List<Map<String, dynamic>> sectionsLookup;
  final Set<String> selectedSchoolIds;
  final Set<String> selectedClassIds;
  final Set<String> selectedSectionIds;
  final VoidCallback onSelectionChanged;

  const AssignStudentsSection({
    super.key,
    required this.schoolsLookup,
    required this.classesLookup,
    required this.sectionsLookup,
    required this.selectedSchoolIds,
    required this.selectedClassIds,
    required this.selectedSectionIds,
    required this.onSelectionChanged,
  });

  String _getDisplayValue({
    required Set<String> selectedIds,
    required List<Map<String, dynamic>> options,
    required String placeholder,
  }) {
    if (selectedIds.isEmpty) return placeholder;
    if (selectedIds.length == options.length) return 'All';

    final names = options
        .where((opt) => selectedIds.contains(opt['id']?.toString()))
        .map((opt) => opt['name'] as String? ?? '')
        .toList();

    if (names.isEmpty) return placeholder;
    if (names.length <= 3) {
      return names.join(', ');
    }
    return 'Selected (${names.length})';
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign to Students',
          style: AppTextStyles.headerSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 16),
        // Schools dropdown
        ArmsDropdownSelector(
          label: 'Select School',
          value: _getDisplayValue(
            selectedIds: selectedSchoolIds,
            options: schoolsLookup,
            placeholder: 'Select School',
          ),
          onTap: () => showExamMultiSelectSheet(
            context: context,
            title: 'Select School',
            options: schoolsLookup,
            selectedIds: selectedSchoolIds,
            onSelectionChanged: onSelectionChanged,
          ),
        ),
        const SizedBox(height: 16),
        // Classes dropdown
        ArmsDropdownSelector(
          label: 'Select Class',
          value: _getDisplayValue(
            selectedIds: selectedClassIds,
            options: classesLookup,
            placeholder: 'Select Class',
          ),
          onTap: () => showExamMultiSelectSheet(
            context: context,
            title: 'Select Class',
            options: classesLookup,
            selectedIds: selectedClassIds,
            onSelectionChanged: onSelectionChanged,
          ),
        ),
        const SizedBox(height: 16),
        // Sections checkbox wrap list
        _buildLabel('Select Sections'),
        sectionsLookup.isEmpty
            ? Text('No sections available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Virtual "All" card
                  GestureDetector(
                    onTap: () {
                      final isAllSelected = selectedSectionIds.length == sectionsLookup.length;
                      if (isAllSelected) {
                        selectedSectionIds.clear();
                      } else {
                        selectedSectionIds.addAll(sectionsLookup.map((e) => e['id'] as String));
                      }
                      onSelectionChanged();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: (selectedSectionIds.length == sectionsLookup.length)
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (selectedSectionIds.length == sectionsLookup.length)
                              ? AppColors.primary
                              : AppColors.outline.withValues(alpha: 0.3),
                          width: (selectedSectionIds.length == sectionsLookup.length) ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        'All',
                        style: AppTextStyles.labelXs.copyWith(
                          color: (selectedSectionIds.length == sectionsLookup.length)
                              ? AppColors.primary
                              : AppColors.textMain,
                          fontWeight: (selectedSectionIds.length == sectionsLookup.length)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  ...sectionsLookup.map((sec) {
                    final secId = sec['id'] as String;
                    final secName = sec['name'] as String? ?? '';
                    final isChecked = selectedSectionIds.contains(secId);
                    return GestureDetector(
                      onTap: () {
                        if (isChecked) {
                          selectedSectionIds.remove(secId);
                        } else {
                          selectedSectionIds.add(secId);
                        }
                        onSelectionChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked ? AppColors.primary : AppColors.outline.withValues(alpha: 0.3),
                            width: isChecked ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          secName,
                          style: AppTextStyles.labelXs.copyWith(
                            color: isChecked ? AppColors.primary : AppColors.textMain,
                            fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ],
    );
  }
}
