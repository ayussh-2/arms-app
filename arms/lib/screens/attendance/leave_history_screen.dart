import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        showBackButton: true,
      ),
      body: Query(
        options: QueryOptions(
          document: gql(GqlQueries.getLeaves),
          variables: const {}, // fetch all so we can filter flexibly in memory
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
                  Text('Error loading history', style: AppTextStyles.headerSmall),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: refetch,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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

          final rawLeaves = (result.data?['leaves'] as List? ?? []).cast<Map<String, dynamic>>();

          // Filter in memory
          List<Map<String, dynamic>> filteredLeaves = rawLeaves.where((leave) {
            // Filter by search query
            final student = leave['student'] as Map<String, dynamic>? ?? {};
            final studentName = (student['name'] as String? ?? '').toLowerCase();
            final reason = (leave['reason'] as String? ?? '').toLowerCase();
            final type = (leave['leave_type'] as String? ?? '').toLowerCase();
            
            final matchesSearch = _searchQuery.isEmpty ||
                studentName.contains(_searchQuery) ||
                reason.contains(_searchQuery) ||
                type.contains(_searchQuery);

            if (!matchesSearch) return false;

            // Filter by filter chip
            if (_selectedFilter == 'All') return true;
            
            if (_selectedFilter == 'Fever') {
              return type == 'fever';
            } else if (_selectedFilter == 'Casual') {
              return type == 'casual';
            } else if (_selectedFilter == 'Approved') {
              return leave['approved'] == true;
            } else if (_selectedFilter == 'Pending') {
              return leave['approved'] == false && leave['rejected_reason'] == null;
            } else if (_selectedFilter == 'Rejected') {
              return leave['approved'] == false && leave['rejected_reason'] != null;
            }
            return true;
          }).toList();

          return Column(
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
                        final student = leave['student'] as Map<String, dynamic>? ?? {};
                        final studentName = student['name'] ?? 'Unknown Student';
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 2),
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
          );
        },
      ),
    );
  }
}
