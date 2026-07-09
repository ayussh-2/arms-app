import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../widgets/components/arms_avatar.dart';
import '../../../widgets/components/arms_status_badge.dart';

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

    final String statusText;
    final ArmsStatusType statusType;

    if (approved) {
      statusText = 'Approved';
      statusType = ArmsStatusType.success;
    } else if (rejectedReason != null && rejectedReason.isNotEmpty) {
      statusText = 'Rejected';
      statusType = ArmsStatusType.error;
    } else {
      statusText = 'Pending';
      statusType = ArmsStatusType.neutral;
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
            ArmsAvatar(
              imageUrl: student?['image_url'] as String?,
              name: studentName,
              radius: 20,
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
            ArmsStatusBadge(
              label: statusText,
              type: statusType,
            ),
          ],
        ),
      ),
    );
  }
}
