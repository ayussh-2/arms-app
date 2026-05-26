import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Attendance status for a student row.
enum AttendanceStatus { present, absent, unmarked }

/// Dense student row for the attendance feed.
/// Shows avatar (or initials), name, roll number, and P/A toggle buttons.
/// Matches the attendance-sheet.html design.
class ArmsStudentRow extends StatelessWidget {
  const ArmsStudentRow({
    super.key,
    required this.studentName,
    required this.rollNo,
    this.avatarUrl,
    required this.status,
    required this.onStatusChanged,
  });

  final String studentName;
  final String rollNo;
  final String? avatarUrl;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onStatusChanged;

  String get _initials {
    final parts = studentName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return studentName.substring(0, studentName.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(),
          const SizedBox(width: 16),
          // Name + Roll
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName, style: AppTextStyles.bodyMedium),
                Text(rollNo, style: AppTextStyles.labelXs),
              ],
            ),
          ),
          // P / A buttons
          Row(
            children: [
              _StatusButton(
                label: 'P',
                isActive: status == AttendanceStatus.present,
                activeColor: AppColors.primary,
                onTap: () => onStatusChanged(AttendanceStatus.present),
              ),
              const SizedBox(width: 12),
              _StatusButton(
                label: 'A',
                isActive: status == AttendanceStatus.absent,
                activeColor: AppColors.errorText,
                onTap: () => onStatusChanged(AttendanceStatus.absent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: AppColors.surfaceVariant,
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.surfaceVariant,
      child: Text(
        _initials,
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Individual P or A toggle button inside the student row.
class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelXs.copyWith(
              color: isActive ? Colors.white : AppColors.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
