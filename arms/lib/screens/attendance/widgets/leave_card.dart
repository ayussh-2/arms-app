import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/image_url_helper.dart';

String _formatNiceDate(String dateStr) {
  try {
    final parsed = DateTime.parse(dateStr);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[parsed.month - 1]} ${parsed.day}';
  } catch (_) {
    return dateStr;
  }
}

String _formatNiceRange(String fromStr, String? toStr) {
  if (toStr == null || toStr == fromStr) {
    return _formatNiceDate(fromStr);
  }
  try {
    final fromDate = DateTime.parse(fromStr);
    final toDate = DateTime.parse(toStr);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    if (fromDate.month == toDate.month) {
      return '${months[fromDate.month - 1]} ${fromDate.day} — ${toDate.day}';
    } else {
      return '${months[fromDate.month - 1]} ${fromDate.day} — ${months[toDate.month - 1]} ${toDate.day}';
    }
  } catch (_) {
    return '$fromStr — $toStr';
  }
}

class LeaveCard extends StatelessWidget {
  const LeaveCard({super.key, required this.leave, this.student, required this.onTap});
  final Map<String, dynamic> leave;
  final Map<String, dynamic>? student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final studentName = student?['name'] ?? 'Unknown Student';
    final fromDate = leave['from_date'] ?? '';
    final toDate = leave['to_date'];
    final reason = leave['reason'] ?? '';
    final approved = leave['approved'] as bool? ?? false;
    final rejectedReason = leave['rejected_reason'] as String?;

    final String dateDisplay = _formatNiceRange(fromDate, toDate);

    String statusText = 'Pending';
    Color statusBg = AppColors.surfaceVariant;
    Color statusTextColor = AppColors.onSurfaceVariant;

    if (approved) {
      statusText = 'Approved';
      statusBg = AppColors.successBg;
      statusTextColor = AppColors.successText;
    } else if (rejectedReason != null && rejectedReason.isNotEmpty) {
      statusText = 'Rejected';
      statusBg = AppColors.errorBg;
      statusTextColor = AppColors.errorText;
    }

    final String leaveType = (leave['leave_type'] as String? ?? 'casual').toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: (student?['image_url'] != null &&
                      (student!['image_url'] as String).isNotEmpty &&
                      ImageUrlHelper.sanitizeUrl(student!['image_url'] as String) != null)
                  ? NetworkImage(ImageUrlHelper.sanitizeUrl(student!['image_url'] as String)!)
                  : null,
              child: (student?['image_url'] == null ||
                      (student!['image_url'] as String).isEmpty ||
                      ImageUrlHelper.sanitizeUrl(student!['image_url'] as String) == null)
                  ? Text(
                      (studentName.isNotEmpty ? studentName[0] : '?').toUpperCase(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  if (student?['class'] != null || student?['section'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${student?['class']?['name'] ?? ''} • ${student?['section']?['name'] ?? ''}',
                      style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$dateDisplay • $leaveType',
                          style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(AppRadius.roundFull),
              ),
              child: Text(
                statusText,
                style: AppTextStyles.labelXsUppercase.copyWith(
                  color: statusTextColor,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
