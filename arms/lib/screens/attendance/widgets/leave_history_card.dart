import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../widgets/components/arms_avatar.dart';
import '../../../widgets/components/arms_status_badge.dart';

int _calculateDays(String fromStr, String? toStr) {
  try {
    final from = DateTime.parse(fromStr);
    if (toStr == null) return 1;
    final to = DateTime.parse(toStr);
    return to.difference(from).inDays + 1;
  } catch (_) {
    return 1;
  }
}

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

class LeaveHistoryCard extends StatelessWidget {
  const LeaveHistoryCard({super.key, required this.leave, this.student});
  final Map<String, dynamic> leave;
  final Map<String, dynamic>? student;

  @override
  Widget build(BuildContext context) {
    final studentName = student?['name'] ?? 'Unknown Student';
    final fromDate = leave['from_date'] ?? '';
    final toDate = leave['to_date'];
    final leaveType = (leave['leave_type'] as String? ?? 'casual');
    final reason = leave['reason'] ?? '';
    final approved = leave['approved'] as bool? ?? false;
    final rejectedReason = leave['rejected_reason'] as String?;

    final String dateDisplay = _formatNiceRange(fromDate, toDate);
    final days = _calculateDays(fromDate, toDate);
    final daysDisplay = '$days ${days == 1 ? "Day" : "Days"}';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text(
                      studentName,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (student?['class'] != null || student?['section'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${student?['class']?['name'] ?? ''} • ${student?['section']?['name'] ?? ''}',
                        style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      dateDisplay,
                      style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${leaveType.toUpperCase()} • $daysDisplay',
                      style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ArmsStatusBadge(
                label: statusText,
                type: statusType,
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reason,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (rejectedReason != null && rejectedReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: $rejectedReason',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
