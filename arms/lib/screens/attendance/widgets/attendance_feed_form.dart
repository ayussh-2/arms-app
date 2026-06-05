import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/arms_dropdown_selector.dart';
import 'session_chip.dart';

class AttendanceFeedForm extends StatelessWidget {
  const AttendanceFeedForm({
    super.key,
    required this.dateStr,
    required this.isPastDate,
    required this.selectedSession,
    required this.sessions,
    required this.selectedSchoolName,
    required this.selectedClassName,
    required this.selectedSectionName,
    required this.canLoad,
    required this.onPickDate,
    required this.onSessionChanged,
    required this.onShowSchoolPicker,
    required this.onShowClassPicker,
    required this.onShowSectionPicker,
    required this.onLoadRoster,
  });

  final String dateStr;
  final bool isPastDate;
  final int selectedSession;
  final List<String> sessions;
  final String? selectedSchoolName;
  final String? selectedClassName;
  final String? selectedSectionName;
  final bool canLoad;

  final VoidCallback onPickDate;
  final ValueChanged<int> onSessionChanged;
  final VoidCallback onShowSchoolPicker;
  final VoidCallback onShowClassPicker;
  final VoidCallback onShowSectionPicker;
  final VoidCallback onLoadRoster;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArmsDropdownSelector(
          label: 'Date',
          value: dateStr,
          icon: Icons.calendar_today_outlined,
          onTap: onPickDate,
        ),
        if (isPastDate)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              'Warning: Selecting a past date.',
              style: AppTextStyles.labelXs.copyWith(
                color: AppColors.errorText,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.stackLg),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Session',
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
          ),
          itemCount: sessions.length,
          itemBuilder: (_, i) => SessionChip(
            label: sessions[i],
            isSelected: selectedSession == i,
            onTap: () => onSessionChanged(i),
          ),
        ),
        const SizedBox(height: AppSpacing.stackLg),
        ArmsDropdownSelector(
          label: 'School',
          value: selectedSchoolName,
          placeholder: 'Select School',
          onTap: onShowSchoolPicker,
        ),
        const SizedBox(height: AppSpacing.stackLg),
        ArmsDropdownSelector(
          label: 'Class',
          value: selectedClassName,
          placeholder: 'Select Class',
          onTap: onShowClassPicker,
        ),
        const SizedBox(height: AppSpacing.stackLg),
        ArmsDropdownSelector(
          label: 'Section',
          value: selectedSectionName,
          placeholder: 'Select Section',
          onTap: onShowSectionPicker,
        ),
        const SizedBox(height: AppSpacing.stackLg),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canLoad ? onLoadRoster : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canLoad ? AppColors.primary : AppColors.cardSurface,
              foregroundColor: canLoad ? AppColors.onPrimary : AppColors.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.roundFull),
              ),
            ),
            child: Text(
              'List Students',
              style: AppTextStyles.headerSmall.copyWith(
                color: canLoad ? AppColors.onPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
