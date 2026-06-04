import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_segmented_control.dart';
import '../../widgets/arms_dropdown_selector.dart';
import 'leave_management_screen.dart';
import 'export_sheet_widget.dart';
import '../../core/auth/auth_service.dart';
import '../../core/utils/logger.dart';

class AttendanceConfigScreen extends StatefulWidget {
  const AttendanceConfigScreen({super.key});

  @override
  State<AttendanceConfigScreen> createState() => _AttendanceConfigScreenState();
}

class _AttendanceConfigScreenState extends State<AttendanceConfigScreen> {
  int _tabIndex = 0;
  DateTime _selectedDate = DateTime.now();
  int _selectedSession = 0;
  int _refreshKey = 0;

  bool _isLoadingLookups = true;
  String? _lookupError;
  bool _hasFetched = false;

  List<dynamic> _schools = [];
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];

  String? _selectedSchoolId;
  String? _selectedSchoolName;
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSectionId;
  String? _selectedSectionName;

  static const _sessions = [
    'Morning In',
    'Morning Out',
    'Evening In',
    'Evening Out',
  ];

  bool get _canLoad =>
      _selectedSchoolId != null &&
      _selectedClassId != null &&
      _selectedSectionId != null;

  String get _sessionKey {
    const keys = ['morning_in', 'morning_out', 'evening_in', 'evening_out'];
    return keys[_selectedSession];
  }

  bool get _isPastDate {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(_selectedDate).isBefore(today);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFetched) {
      _hasFetched = true;
      _fetchLookups();
    }
  }

  Future<void> _fetchLookups() async {
    armsLog('=== [AttendanceConfigScreen] Starting _fetchLookups ===');
    final admin = AuthService.currentAdmin;
    armsLog(
      '=== [AttendanceConfigScreen] currentAdmin: ${admin?.name}, adminID: ${admin?.adminID} ===',
    );
    armsLog(
      '=== [AttendanceConfigScreen] organization: ${admin?.organization?.name}, orgId: ${admin?.organization?.id} ===',
    );
    final orgId = admin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      setState(() {
        _isLoadingLookups = false;
        _lookupError =
            'No organization associated with this account. Please log out and log in again.';
      });
      return;
    }

    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });

    try {
      armsLog('=== [AttendanceConfigScreen] Fetching client... ===');
      final client = GraphQLProvider.of(context).value;
      armsLog(
        '=== [AttendanceConfigScreen] Client fetched, querying with orgId=$orgId ===',
      );
      final result = await client
          .query(
            QueryOptions(
              document: gql(GqlQueries.getLookups),
              variables: {'organisationId': orgId},
              fetchPolicy: FetchPolicy.networkOnly,
            ),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout:
                () =>
                    throw TimeoutException(
                      'getLookups query timed out after 10s. Is the backend running?',
                    ),
          );
      armsLog(
        '=== [AttendanceConfigScreen] Query completed. Has exception? ${result.hasException} ===',
      );

      if (!mounted) return;

      if (result.hasException) {
        armsLog(
          '=== [AttendanceConfigScreen] Exception: ${result.exception.toString()} ===',
        );
        setState(() {
          _isLoadingLookups = false;
          _lookupError =
              'Failed to load lookups: ${result.exception.toString()}';
        });
        return;
      }

      final lookups = result.data?['getLookups'];
      if (lookups == null) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'No lookup data returned from server.';
        });
        return;
      }

      setState(() {
        _schools = List.from(lookups['schools'] ?? []);
        _classes = List.from(lookups['classes'] ?? []);
        _sections = List.from(lookups['sections'] ?? []);
        _isLoadingLookups = false;
      });
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError =
              e.message ?? 'Request timed out. Check backend connection.';
        });
      }
    } catch (e) {
      armsLog('=== [AttendanceConfigScreen] Catch error: $e ===');
      if (mounted) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'Connection error: $e';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showSchoolPicker() {
    if (_schools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No schools available'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Select School', style: AppTextStyles.headerSmall),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _schools.length,
                    itemBuilder: (_, i) {
                      final s = _schools[i];
                      return ListTile(
                        title: Text(
                          s['name'] ?? '',
                          style: AppTextStyles.bodyMedium,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedSchoolId = s['id']?.toString();
                            _selectedSchoolName = s['name']?.toString();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showClassPicker() {
    if (_classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No classes available'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Select Class', style: AppTextStyles.headerSmall),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _classes.length,
                    itemBuilder: (_, i) {
                      final c = _classes[i];
                      return ListTile(
                        title: Text(
                          c['name'] ?? '',
                          style: AppTextStyles.bodyMedium,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedClassId = c['id']?.toString();
                            _selectedClassName = c['name']?.toString();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showSectionPicker() {
    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sections available'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Select Section', style: AppTextStyles.headerSmall),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sections.length,
                    itemBuilder: (_, i) {
                      final s = _sections[i];
                      return ListTile(
                        title: Text(
                          s['name'] ?? '',
                          style: AppTextStyles.bodyMedium,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedSectionId = s['id']?.toString();
                            _selectedSectionName = s['name']?.toString();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _loadRoster() {
    if (!_canLoad) return;
    Navigator.of(context).pushNamed(
      '/attendance-feed',
      arguments: {
        'schoolId': _selectedSchoolId,
        'schoolName': _selectedSchoolName,
        'classId': _selectedClassId,
        'sectionId': _selectedSectionId,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'sessionKey': _sessionKey,
        'title': '$_selectedClassName - $_selectedSectionName',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(showBackButton: true),
      body:
          _isLoadingLookups
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : _lookupError != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.errorText,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _lookupError!,
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLookups,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  if (_tabIndex == 0) {
                    await _fetchLookups();
                  } else if (_tabIndex == 1) {
                    setState(() {
                      _refreshKey++;
                    });
                    await Future.delayed(const Duration(milliseconds: 600));
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginPage,
                    vertical: AppSpacing.stackMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tabIndex == 1
                            ? 'Leave Management'
                            : _tabIndex == 2
                            ? 'Export PDF/Sheet'
                            : 'Attendance',
                        style: AppTextStyles.displayLarge,
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      ArmsSegmentedControl(
                        options: const ['Feed', 'Leave', 'Sheet'],
                        selectedIndex: _tabIndex,
                        onChanged: (i) => setState(() => _tabIndex = i),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      if (_tabIndex == 0) ..._buildFeedTab(dateStr),
                      if (_tabIndex == 1)
                        LeaveManagementWidget(key: ValueKey(_refreshKey)),
                      if (_tabIndex == 2) const ExportSheetWidget(),
                    ],
                  ),
                ),
              ),
      floatingActionButton:
          _tabIndex == 1
              ? FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/leave-apply',
                  );
                  if (result == true) {
                    setState(() {
                      _refreshKey++;
                    });
                  }
                },
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  List<Widget> _buildFeedTab(String dateStr) {
    return [
      ArmsDropdownSelector(
        label: 'Date',
        value: dateStr,
        icon: Icons.calendar_today_outlined,
        onTap: _pickDate,
      ),
      if (_isPastDate)
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Text(
            'Warning: Selecting a past date.',
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.errorText,
              fontSize: 13,
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.stackLg),
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text(
          'Session',
          style: AppTextStyles.labelXs.copyWith(
            color: AppColors.textMain,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.2,
        ),
        itemCount: _sessions.length,
        itemBuilder:
            (_, i) => _SessionChip(
              label: _sessions[i],
              isSelected: _selectedSession == i,
              onTap: () => setState(() => _selectedSession = i),
            ),
      ),
      const SizedBox(height: AppSpacing.stackLg),
      ArmsDropdownSelector(
        label: 'School',
        value: _selectedSchoolName,
        placeholder: 'Select School',
        onTap: _showSchoolPicker,
      ),
      const SizedBox(height: AppSpacing.stackLg),
      ArmsDropdownSelector(
        label: 'Class',
        value: _selectedClassName,
        placeholder: 'Select Class',
        onTap: _showClassPicker,
      ),
      const SizedBox(height: AppSpacing.stackLg),
      ArmsDropdownSelector(
        label: 'Section',
        value: _selectedSectionName,
        placeholder: 'Select Section',
        onTap: _showSectionPicker,
      ),
      const SizedBox(height: AppSpacing.stackLg),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _canLoad ? _loadRoster : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canLoad ? AppColors.primary : AppColors.cardSurface,
            foregroundColor:
                _canLoad ? AppColors.onPrimary : AppColors.textSecondary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.roundFull),
            ),
          ),
          child: Text(
            'List Students',
            style: AppTextStyles.headerSmall.copyWith(
              color: _canLoad ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _placeholder(String t, IconData ic) => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Center(
      child: Column(
        children: [
          Icon(ic, size: 64, color: AppColors.outline),
          const SizedBox(height: 16),
          Text(t, style: AppTextStyles.headerSmall),
          const SizedBox(height: 8),
          Text('Coming soon', style: AppTextStyles.labelXs),
        ],
      ),
    ),
  );

  String _formatDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final today = DateUtils.dateOnly(DateTime.now());
    final prefix = DateUtils.dateOnly(d) == today ? 'Today, ' : '';
    return '$prefix${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.roundFull),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : AppColors.outlineMediumLight,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
