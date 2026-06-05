import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import 'widgets/leave_history_card.dart';

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
          SnackBar(content: Text('Error loading leave history: $e'), backgroundColor: AppColors.errorText),
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
      return const Scaffold(
        backgroundColor: AppColors.background,
        appBar: ArmsTopAppBar(showBackButton: true),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Past Leaves', style: AppTextStyles.displayMobile),
                const SizedBox(height: 16),
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
                  ...filteredLeaves.map((leave) => LeaveHistoryCard(
                        leave: leave,
                        student: leave['student'] as Map<String, dynamic>?,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
