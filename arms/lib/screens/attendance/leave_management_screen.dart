import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';

class LeaveManagementWidget extends StatefulWidget {
  const LeaveManagementWidget({super.key});

  @override
  State<LeaveManagementWidget> createState() => _LeaveManagementWidgetState();
}

class _LeaveManagementWidgetState extends State<LeaveManagementWidget> {
  String _selectedFilter = 'All'; // 'All', 'Approved', 'Pending', 'Rejected'
  final List<String> _filters = ['All', 'Approved', 'Pending', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    final statusQueryParam = _selectedFilter == 'All' ? null : _selectedFilter;

    return Query(
      options: QueryOptions(
        document: gql(GqlQueries.getLeaves),
        variables: {'status': statusQueryParam},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
        if (result.hasException) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.errorText, size: 48),
                const SizedBox(height: 16),
                Text('Error loading leaves', style: AppTextStyles.headerSmall),
                const SizedBox(height: 8),
                Text(result.exception.toString(), style: AppTextStyles.labelXs, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: refetch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (result.isLoading && result.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final leavesList = (result.data?['leaves'] as List? ?? []).cast<Map<String, dynamic>>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Leave Management', style: AppTextStyles.displayMobile),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: 'Refresh Leaves',
                  onPressed: () {
                    refetch?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshing leaves...'),
                        duration: Duration(milliseconds: 800),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),

            // Horizontal Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final filter = _filters[idx];
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(AppRadius.roundFull),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : AppColors.outline.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          filter,
                          style: AppTextStyles.labelXs.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.onPrimary : AppColors.textMain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Leaves list
            if (leavesList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.event_available, size: 64, color: AppColors.outline),
                      const SizedBox(height: 16),
                      Text('No leave records found', style: AppTextStyles.headerSmall),
                      const SizedBox(height: 8),
                      Text('All students are present or no applications match this filter.', style: AppTextStyles.labelXs),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leavesList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final leave = leavesList[idx];
                  return _LeaveCard(
                    leave: leave,
                    onTap: () => _showLeaveDetailsSheet(context, leave, refetch),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _showLeaveDetailsSheet(BuildContext context, Map<String, dynamic> leave, VoidCallback? refetch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _LeaveApprovalBottomSheet(leave: leave, onUpdated: refetch),
    );
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

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave, required this.onTap});
  final Map<String, dynamic> leave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final student = leave['student'] as Map<String, dynamic>? ?? {};
    final studentName = student['name'] ?? 'Unknown Student';
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
          border: Border.all(color: AppColors.outline.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
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

class _LeaveApprovalBottomSheet extends StatefulWidget {
  const _LeaveApprovalBottomSheet({required this.leave, this.onUpdated});
  final Map<String, dynamic> leave;
  final VoidCallback? onUpdated;

  @override
  State<_LeaveApprovalBottomSheet> createState() => _LeaveApprovalBottomSheetState();
}

class _LeaveApprovalBottomSheetState extends State<_LeaveApprovalBottomSheet> {
  late bool _isApproved;
  late TextEditingController _rejectedReasonController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final approved = widget.leave['approved'] as bool? ?? false;
    final rejectedReason = widget.leave['rejected_reason'] as String?;
    
    // Default approved to true if it's pending, otherwise show actual status
    final isPending = !approved && (rejectedReason == null || rejectedReason.isEmpty);
    _isApproved = isPending ? true : approved;
    
    _rejectedReasonController = TextEditingController(text: rejectedReason ?? '');
  }

  @override
  void dispose() {
    _rejectedReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.leave['student'] as Map<String, dynamic>? ?? {};
    final studentName = student['name'] ?? 'Unknown Student';
    final studentRoll = student['roll_no']?.toString() ?? '';
    final studentAvatar = student['image_url'] as String?;
    final fromDate = widget.leave['from_date'] ?? '';
    final toDate = widget.leave['to_date'];
    final leaveType = widget.leave['leave_type'] as String? ?? 'casual';
    final reason = widget.leave['reason'] ?? '';

    final String dateDisplay = _formatNiceRange(fromDate, toDate);

    return Mutation(
      options: MutationOptions(
        document: gql(GqlQueries.updateLeaveStatus),
        onCompleted: (data) {
          if (widget.onUpdated != null) {
            widget.onUpdated!();
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave status updated successfully'),
              backgroundColor: AppColors.successText,
            ),
          );
        },
        onError: (error) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating status: ${error?.toString()}'),
              backgroundColor: AppColors.errorText,
            ),
          );
        },
      ),
      builder: (RunMutation runMutation, QueryResult? result) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.marginPage,
            right: AppSpacing.marginPage,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom sheet drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text('Review Leave Application', style: AppTextStyles.headerSmall),
              const SizedBox(height: AppSpacing.stackMd),

              // Student Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                  border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: studentAvatar != null ? NetworkImage(studentAvatar) : null,
                      child: studentAvatar == null
                          ? Text(
                              studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          Text('Roll No: $studentRoll', style: AppTextStyles.labelXs),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),

              // Details (Date, Type, Reason)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE', style: AppTextStyles.labelXsUppercase),
                        const SizedBox(height: 2),
                        Text(dateDisplay, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TYPE', style: AppTextStyles.labelXsUppercase),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          leaveType.toUpperCase(),
                          style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),

              if (reason.isNotEmpty) ...[
                Text('REASON', style: AppTextStyles.labelXsUppercase),
                const SizedBox(height: 4),
                Text(reason, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.stackMd),
              ],

              const Divider(),
              const SizedBox(height: AppSpacing.stackMd),

              // Approval Controls (Approved switch, Rejected Reason)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Approved', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  Switch(
                    value: _isApproved,
                    activeColor: AppColors.onPrimary,
                    activeTrackColor: AppColors.primary,
                    inactiveThumbColor: AppColors.outlineMedium,
                    inactiveTrackColor: AppColors.surfaceVariant,
                    onChanged: (val) {
                      setState(() {
                        _isApproved = val;
                        if (val) {
                          _rejectedReasonController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),

              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: !_isApproved
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejected Reason (forces Approved to OFF)',
                            style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _rejectedReasonController,
                            onChanged: (val) {
                              if (val.trim().isNotEmpty && _isApproved) {
                                setState(() => _isApproved = false);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'If rejected, specify why...',
                              hintStyle: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                              fillColor: AppColors.cardSurface,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.roundEight),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              // Save Action Button
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() => _isSaving = true);
                          runMutation({
                            'id': widget.leave['id'],
                            'approved': _isApproved,
                            'rejectedReason': !_isApproved && _rejectedReasonController.text.trim().isNotEmpty
                                ? _rejectedReasonController.text.trim()
                                : null,
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppColors.onPrimary)
                      : Text('Save Decisions', style: AppTextStyles.headerSmall.copyWith(color: AppColors.onPrimary)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
