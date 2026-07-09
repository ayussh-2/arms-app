import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/arms_dropdown_selector.dart';
import 'student_photo_empty_state.dart';
import '../../../widgets/components/arms_avatar.dart';

class StudentPhotoListPanel extends StatelessWidget {
  const StudentPhotoListPanel({
    super.key,
    required this.schools,
    required this.classes,
    required this.sections,
    required this.selectedSchoolName,
    required this.selectedClassName,
    required this.selectedSectionName,
    required this.selectedClassId,
    required this.selectedSectionId,
    required this.isLoadingStudents,
    required this.studentsError,
    required this.filteredStudents,
    required this.searchController,
    required this.onShowSchoolPicker,
    required this.onShowClassPicker,
    required this.onShowSectionPicker,
    required this.onFetchStudents,
    required this.onStudentSelected,
  });

  final List<dynamic> schools;
  final List<dynamic> classes;
  final List<dynamic> sections;
  final String? selectedSchoolName;
  final String? selectedClassName;
  final String? selectedSectionName;
  final String? selectedClassId;
  final String? selectedSectionId;
  final bool isLoadingStudents;
  final String? studentsError;
  final List<dynamic> filteredStudents;
  final TextEditingController searchController;

  final VoidCallback onShowSchoolPicker;
  final VoidCallback onShowClassPicker;
  final VoidCallback onShowSectionPicker;
  final VoidCallback onFetchStudents;
  final ValueChanged<Map<String, dynamic>> onStudentSelected;



  @override
  Widget build(BuildContext context) {
    final hasFilterSelected = selectedClassId != null && selectedSectionId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginPage,
        vertical: AppSpacing.stackMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          if (schools.length > 1) ...[
            ArmsDropdownSelector(
              label: 'School',
              value: selectedSchoolName,
              placeholder: 'Select School',
              onTap: onShowSchoolPicker,
            ),
            const SizedBox(height: AppSpacing.stackMd),
          ],
          Row(
            children: [
              Expanded(
                child: ArmsDropdownSelector(
                  label: 'Class',
                  value: selectedClassName,
                  placeholder: 'Select Class',
                  onTap: onShowClassPicker,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ArmsDropdownSelector(
                  label: 'Section',
                  value: selectedSectionName,
                  placeholder: 'Select Section',
                  onTap: onShowSectionPicker,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackLg),

          // Search & List Section
          Expanded(
            child: !hasFilterSelected
                ? const StudentPhotoEmptyState(
                    icon: Icons.school_outlined,
                    title: 'Select Class & Section',
                    subtitle: 'Choose a class and section above to display and capture student profile photos.',
                  )
                : isLoadingStudents
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : studentsError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  studentsError!,
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorText),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: onFetchStudents,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Search field
                              TextField(
                                controller: searchController,
                                style: AppTextStyles.bodyMedium,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.cardSurface,
                                  hintText: 'Search by name or roll number...',
                                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                                  suffixIcon: searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                          onPressed: () {
                                            searchController.clear();
                                          },
                                        )
                                      : null,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.roundFull),
                                    borderSide: BorderSide(
                                      color: AppColors.outline.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.roundFull),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.stackMd),

                              // Student List
                              Expanded(
                                child: filteredStudents.isEmpty
                                    ? const StudentPhotoEmptyState(
                                        icon: Icons.search_off_outlined,
                                        title: 'No Students Found',
                                        subtitle: 'Try searching with a different name or roll number.',
                                      )
                                    : ListView.builder(
                                        itemCount: filteredStudents.length,
                                        itemBuilder: (context, index) {
                                          final student = filteredStudents[index];
                                          final name = student['name'] ?? 'No Name';
                                          final rollNo = student['roll_no'] ?? 'No Roll No';
                                          final imgUrl = student['image_url'] as String?;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.outline.withValues(alpha: 0.08),
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                              leading: ArmsAvatar(
                                                  imageUrl: imgUrl,
                                                  name: name,
                                                  radius: 24,
                                                  backgroundColor: AppColors.cardSurface,
                                                  foregroundColor: AppColors.textSecondary,
                                                ),
                                              title: Text(
                                                name,
                                                style: AppTextStyles.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Roll: $rollNo',
                                                style: AppTextStyles.labelXs,
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right_rounded,
                                                color: AppColors.textSecondary,
                                              ),
                                              onTap: () => onStudentSelected(Map<String, dynamic>.from(student)),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
