import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';

class ExportOptionsCard extends StatelessWidget {
  const ExportOptionsCard({
    super.key,
    required this.includeStudentPic,
    required this.showRollNo,
    required this.showSchool,
    required this.showClassSection,
    required this.isShortStatus,
    required this.coloredStatus,
    required this.isLightTheme,
    required this.showHolidays,
    required this.showSundays,
    required this.removeBlankRows,
    required this.showRemarks,
    required this.hideUnmarkedDays,
    required this.datesDescending,
    required this.onIncludeStudentPicChanged,
    required this.onShowRollNoChanged,
    required this.onShowSchoolChanged,
    required this.onShowClassSectionChanged,
    required this.onIsShortStatusChanged,
    required this.onColoredStatusChanged,
    required this.onIsLightThemeChanged,
    required this.onShowHolidaysChanged,
    required this.onShowSundaysChanged,
    required this.onRemoveBlankRowsChanged,
    required this.onShowRemarksChanged,
    required this.onHideUnmarkedDaysChanged,
    required this.onDatesDescendingChanged,
  });

  final bool includeStudentPic;
  final bool showRollNo;
  final bool showSchool;
  final bool showClassSection;
  final bool isShortStatus;
  final bool coloredStatus;
  final bool isLightTheme;
  final bool showHolidays;
  final bool showSundays;
  final bool removeBlankRows;
  final bool showRemarks;
  final bool hideUnmarkedDays;
  final bool datesDescending;

  final ValueChanged<bool> onIncludeStudentPicChanged;
  final ValueChanged<bool> onShowRollNoChanged;
  final ValueChanged<bool> onShowSchoolChanged;
  final ValueChanged<bool> onShowClassSectionChanged;
  final ValueChanged<bool> onIsShortStatusChanged;
  final ValueChanged<bool> onColoredStatusChanged;
  final ValueChanged<bool> onIsLightThemeChanged;
  final ValueChanged<bool> onShowHolidaysChanged;
  final ValueChanged<bool> onShowSundaysChanged;
  final ValueChanged<bool> onRemoveBlankRowsChanged;
  final ValueChanged<bool> onShowRemarksChanged;
  final ValueChanged<bool> onHideUnmarkedDaysChanged;
  final ValueChanged<bool> onDatesDescendingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toggleRow('Include Student Photo', includeStudentPic, onIncludeStudentPicChanged),
          _toggleRow('Show Roll No', showRollNo, onShowRollNoChanged),
          _toggleRow('Show School', showSchool, onShowSchoolChanged),
          _toggleRow('Show Class/Section', showClassSection, onShowClassSectionChanged),
          _toggleRow('Short Status (P / A)', isShortStatus, onIsShortStatusChanged),
          _toggleRow('Colored Status labels', coloredStatus, onColoredStatusChanged),
          _toggleRow('Light Theme', isLightTheme, onIsLightThemeChanged),
          _toggleRow('Show Holidays', showHolidays, onShowHolidaysChanged),
          _toggleRow('Show Sundays', showSundays, onShowSundaysChanged),
          _toggleRow('Remove Blank Rows', removeBlankRows, onRemoveBlankRowsChanged),
          _toggleRow('Show Remarks', showRemarks, onShowRemarksChanged),
          _toggleRow('Hide Unmarked Days', hideUnmarkedDays, onHideUnmarkedDaysChanged),
          _toggleRow('Dates Descending', datesDescending, onDatesDescendingChanged),
        ],
      ),
    );
  }

  Widget _toggleRow(String title, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Switch.adaptive(
            value: val,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
