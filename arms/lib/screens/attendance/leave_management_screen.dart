import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import 'widgets/leave_card.dart';
import 'widgets/leave_approval_bottom_sheet.dart';

class LeaveManagementWidget extends StatefulWidget {
  const LeaveManagementWidget({super.key});

  @override
  State<LeaveManagementWidget> createState() => _LeaveManagementWidgetState();
}

class _LeaveManagementWidgetState extends State<LeaveManagementWidget> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Approved', 'Pending', 'Rejected'];

  List<Map<String, dynamic>> _leavesList = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadData();
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final client = GraphQLProvider.of(context).value;
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        throw Exception("Missing organization ID. Please log in again.");
      }

      final leavesRes = await client.query(QueryOptions(
        document: gql(GqlQueries.getLeaves),
        variables: {'organisationId': orgId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (leavesRes.hasException) {
        throw leavesRes.exception!;
      }

      final leavesData = leavesRes.data?['getLeaves'];
      final rawLeaves = (leavesData is List)
          ? leavesData.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _leavesList = rawLeaves;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leaves: $e'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final filteredLeaves = _leavesList.where((leave) {
      final approved = leave['approved'] == true;
      final rejectedReason = leave['rejected_reason'] as String?;
      final isPending = !approved && (rejectedReason == null || rejectedReason.isEmpty);

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Approved') return approved;
      if (_selectedFilter == 'Pending') return isPending;
      if (_selectedFilter == 'Rejected') return !approved && rejectedReason != null && rejectedReason.isNotEmpty;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        if (filteredLeaves.isEmpty)
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
            itemCount: filteredLeaves.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final leave = filteredLeaves[idx];
              final student = leave['student'] as Map<String, dynamic>?;

              return LeaveCard(
                leave: leave,
                student: student,
                onTap: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/leave-apply',
                    arguments: {
                      'leave': leave,
                      'student': student,
                    },
                  );
                  if (result == true) {
                    setState(() => _isLoading = true);
                    _loadData();
                  }
                },
              );
            },
          ),
      ],
    );
  }

  void showLeaveDetailsSheet(BuildContext context, Map<String, dynamic> leave, Map<String, dynamic>? student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LeaveApprovalBottomSheet(
        leave: leave,
        student: student,
        onUpdated: () {
          setState(() => _isLoading = true);
          _loadData();
        },
      ),
    );
  }
}
