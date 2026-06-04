import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../core/utils/image_url_helper.dart';
import '../../core/utils/logger.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Fever', 'Casual', 'Approved', 'Pending', 'Rejected'];

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    armsLog('=== [LeaveHistoryScreen] Starting _loadData ===');
    try {
      final client = GraphQLProvider.of(context).value;
      final orgId = AuthService.currentAdmin?.organization?.id;
      armsLog('=== [LeaveHistoryScreen] orgId: $orgId ===');
      if (orgId == null) {
        throw Exception("Missing organization ID. Please log in again.");
      }

      armsLog('=== [LeaveHistoryScreen] Querying leaves... ===');
      final leavesRes = await client.query(QueryOptions(
        document: gql(GqlQueries.getLeaves),
        variables: {'organisationId': orgId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      armsLog('=== [LeaveHistoryScreen] leavesRes hasException: ${leavesRes.hasException} ===');

      if (leavesRes.hasException) {
        armsLog('=== [LeaveHistoryScreen] Leaves query exception: ${leavesRes.exception} ===');
        throw leavesRes.exception!;
      }

      final leavesData = leavesRes.data?['getLeaves'];
      final rawLeaves = (leavesData is List)
          ? leavesData.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : <Map<String, dynamic>>[];

      armsLog('=== [LeaveHistoryScreen] Fetched ${rawLeaves.length} leaves ===');

      if (mounted) {
        setState(() {
          _leavesList = rawLeaves;
          _isLoading = false;
        });
        armsLog('=== [LeaveHistoryScreen] Data successfully loaded and state updated ===');
      }
    } catch (e, stack) {
      armsLog('=== [LeaveHistoryScreen] Error in _loadData: $e ===');
      armsLog(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leave history: $e'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        appBar: ArmsTopAppBar(showBackButton: true),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Filter leaves in memory
    List<Map<String, dynamic>> filteredLeaves = _leavesList.where((leave) {
      final student = leave['student'] as Map<String, dynamic>?;
      final studentName = (student?['name'] as String? ?? '').toLowerCase();
      final reason = (leave['reason'] as String? ?? '').toLowerCase();
      final type = (leave['leave_type'] as String? ?? '').toLowerCase();
      
      final matchesSearch = _searchQuery.isEmpty ||
          studentName.contains(_searchQuery) ||
          reason.contains(_searchQuery) ||
          type.contains(_searchQuery);

      if (!matchesSearch) return false;

      // Filter by filter chip
      if (_selectedFilter == 'All') return true;
      
      final approved = leave['approved'] == true;
      final rejectedReason = leave['rejected_reason'] as String?;
      final isPending = !approved && (rejectedReason == null || rejectedReason.isEmpty);

      if (_selectedFilter == 'Fever') {
        return type == 'fever';
      } else if (_selectedFilter == 'Casual') {
        return type == 'casual';
      } else if (_selectedFilter == 'Approved') {
        return approved;
      } else if (_selectedFilter == 'Pending') {
        return isPending;
      } else if (_selectedFilter == 'Rejected') {
        return !approved && rejectedReason != null && rejectedReason.isNotEmpty;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        showBackButton: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Search Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Past Leaves', style: AppTextStyles.displayMobile),
                const SizedBox(height: 16),
                // Search box
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(AppRadius.roundFull),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      hintText: 'Search history...',
                      hintStyle: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
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
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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

          // Recent Records Header & List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
              children: [
                Text('RECENT RECORDS', style: AppTextStyles.labelXsUppercase),
                const SizedBox(height: 12),
                if (filteredLeaves.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.history_toggle_off, size: 64, color: AppColors.outline),
                          const SizedBox(height: 16),
                          Text('No past records found', style: AppTextStyles.headerSmall),
                          const SizedBox(height: 8),
                          Text('Try adjusting your search query or filter chip.', style: AppTextStyles.labelXs),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(filteredLeaves.length, (idx) {
                    final leave = filteredLeaves[idx];
                    final student = leave['student'] as Map<String, dynamic>?;
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                        border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: (student?['image_url'] != null && (student!['image_url'] as String).isNotEmpty)
                                    ? NetworkImage(ImageUrlHelper.sanitizeUrl(student!['image_url'] as String)!)
                                    : null,
                                child: (student?['image_url'] == null || (student!['image_url'] as String).isEmpty)
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
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
