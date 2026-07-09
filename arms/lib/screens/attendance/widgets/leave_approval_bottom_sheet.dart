import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/graphql/queries.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../widgets/components/arms_button.dart';
import '../../../widgets/components/arms_textarea_field.dart';
import '../../../widgets/components/arms_avatar.dart';
import '../../../widgets/components/arms_confirm_dialog.dart';

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

class LeaveApprovalBottomSheet extends StatefulWidget {
  const LeaveApprovalBottomSheet({super.key, required this.leave, this.student, this.onUpdated});
  final Map<String, dynamic> leave;
  final Map<String, dynamic>? student;
  final VoidCallback? onUpdated;

  @override
  State<LeaveApprovalBottomSheet> createState() => _LeaveApprovalBottomSheetState();
}

class _LeaveApprovalBottomSheetState extends State<LeaveApprovalBottomSheet> {
  late bool _isApproved;
  late TextEditingController _rejectedReasonController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final approved = widget.leave['approved'] as bool? ?? false;
    final rejectedReason = widget.leave['rejected_reason'] as String?;
    
    final isPending = !approved && (rejectedReason == null || rejectedReason.isEmpty);
    _isApproved = isPending ? true : approved;
    
    _rejectedReasonController = TextEditingController(text: rejectedReason ?? '');
  }

  @override
  void dispose() {
    _rejectedReasonController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String leaveId) async {
    final confirmed = await ArmsConfirmDialog.show(
      context,
      title: 'Delete Leave Application',
      message: 'Are you sure you want to delete this leave application? This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isSaving = true);
      try {
        final client = GraphQLProvider.of(context).value;
        final orgId = AuthService.currentAdmin?.organization?.id;
        if (orgId == null) throw Exception("Missing organization ID.");

        final result = await client.mutate(MutationOptions(
          document: gql(GqlQueries.deleteLeave),
          variables: {
            'id': leaveId,
            'organisationId': orgId,
          },
        ));

        if (result.hasException) {
          throw result.exception!;
        }

        if (widget.onUpdated != null) {
          widget.onUpdated!();
        }

        if (mounted) {
          Navigator.pop(context); // Close bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave application deleted successfully'),
              backgroundColor: AppColors.successText,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting leave: $e'),
              backgroundColor: AppColors.errorText,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.student?['name'] ?? 'Unknown Student';
    final studentRoll = widget.student?['roll_no']?.toString() ?? '';
    final studentAvatar = ImageUrlHelper.sanitizeUrl(widget.student?['image_url'] as String?);
    final fromDate = widget.leave['from_date'] ?? '';
    final toDate = widget.leave['to_date'];
    final leaveType = widget.leave['leave_type'] as String? ?? 'casual';
    final reason = widget.leave['reason'] ?? '';

    final String dateDisplay = _formatNiceRange(fromDate, toDate);

    return Mutation(
      options: MutationOptions(
        document: gql(GqlQueries.updateLeave),
      ),
      builder: (RunMutation runUpdate, QueryResult? result) {
        final isLoading = _isSaving || (result?.isLoading ?? false);

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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Review Leave Application', style: AppTextStyles.headerSmall),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.errorText),
                    onPressed: () => _confirmDelete(widget.leave['id']),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    ArmsAvatar(
                      imageUrl: studentAvatar,
                      name: studentName,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '${widget.student?['class']?['name'] ?? ''} • ${widget.student?['section']?['name'] ?? ''}${studentRoll.isNotEmpty ? " • Roll No: $studentRoll" : ""}',
                            style: AppTextStyles.labelXs,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),

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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Approved', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  Switch(
                    value: _isApproved,
                    activeThumbColor: AppColors.onPrimary,
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
                            'Rejected Reason',
                            style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          ArmsTextAreaField(
                            controller: _rejectedReasonController,
                            hintText: 'If rejected, specify why...',
                            maxLines: 3,
                            onChanged: (val) {
                              if (val.trim().isNotEmpty && _isApproved) {
                                setState(() => _isApproved = false);
                              }
                            },
                            fillColor: AppColors.cardSurface,
                            hasBorder: false,
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),
              ArmsButton(
                label: 'Save Decisions',
                isLoading: isLoading,
                variant: ArmsButtonVariant.primary,
                size: ArmsButtonSize.large,
                fullWidth: true,
                onPressed: () async {
                          setState(() => _isSaving = true);
                          try {
                            final res = await runUpdate({
                              'input': {
                                'id': widget.leave['id'],
                                'organisation_id': AuthService.currentAdmin?.organization?.id,
                                'student_id': widget.leave['student_id'],
                                'from_date': widget.leave['from_date'],
                                'to_date': widget.leave['to_date'],
                                'leave_type': widget.leave['leave_type'],
                                'reason': widget.leave['reason'],
                                'approved': _isApproved,
                                'approved_by': AuthService.currentAdmin?.id,
                                'leave_application_image_url': widget.leave['leave_application_image_url'],
                                'rejected_reason': !_isApproved && _rejectedReasonController.text.trim().isNotEmpty
                                    ? _rejectedReasonController.text.trim()
                                    : null,
                              }
                            }).networkResult;

                            if (res?.hasException == true) {
                              throw res!.exception!;
                            }

                            if (widget.onUpdated != null) {
                              widget.onUpdated!();
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Leave status updated successfully'),
                                  backgroundColor: AppColors.successText,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.errorText,
                                ),
                              );
                            }
                          }
                        },
              ),
            ],
          ),
        );
      },
    );
  }
}
