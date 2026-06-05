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
import '../../widgets/arms_picker_sheet.dart';
import '../../widgets/arms_snackbar.dart';
import '../../core/utils/app_date_utils.dart';
import 'leave_management_screen.dart';
import 'export_sheet_widget.dart';
import 'widgets/session_chip.dart';
import 'widgets/attendance_feed_form.dart';
import '../../core/auth/auth_service.dart';

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
    final admin = AuthService.currentAdmin;
    final orgId = admin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'No organization associated with this account. Please log out and log in again.';
      });
      return;
    }

    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getLookups),
          variables: {'organisationId': orgId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('getLookups query timed out after 10s. Is the backend running?'),
      );
      if (!mounted) return;

      if (result.hasException) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'Failed to load lookups: ${result.exception.toString()}';
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
          _lookupError = e.message ?? 'Request timed out. Check backend connection.';
        });
      }
    } catch (e) {
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showPicker({
    required String title,
    required List<dynamic> items,
    required String errorMsg,
    required void Function(dynamic) onSelected,
  }) {
    if (items.isEmpty) {
      ArmsSnackbar.showError(context, errorMsg);
      return;
    }
    ArmsPickerSheet.show<dynamic>(
      context: context,
      title: title,
      items: items,
      itemLabel: (item) => item['name']?.toString() ?? '',
      onItemSelected: onSelected,
    );
  }

  void _showSchoolPicker() => _showPicker(
    title: 'Select School',
    items: _schools,
    errorMsg: 'No schools available',
    onSelected: (s) => setState(() {
      _selectedSchoolId = s['id']?.toString();
      _selectedSchoolName = s['name']?.toString();
    }),
  );

  void _showClassPicker() => _showPicker(
    title: 'Select Class',
    items: _classes,
    errorMsg: 'No classes available',
    onSelected: (c) => setState(() {
      _selectedClassId = c['id']?.toString();
      _selectedClassName = c['name']?.toString();
    }),
  );

  void _showSectionPicker() => _showPicker(
    title: 'Select Section',
    items: _sections,
    errorMsg: 'No sections available',
    onSelected: (s) => setState(() {
      _selectedSectionId = s['id']?.toString();
      _selectedSectionName = s['name']?.toString();
    }),
  );

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
    final dateStr = AppDateUtils.formatToDMY(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(showBackButton: true),
      body: _isLoadingLookups
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
                                  ? 'Export PDF/ Sheet'
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
                        if (_tabIndex == 0)
                          AttendanceFeedForm(
                            dateStr: dateStr,
                            isPastDate: _isPastDate,
                            selectedSession: _selectedSession,
                            sessions: _sessions,
                            selectedSchoolName: _selectedSchoolName,
                            selectedClassName: _selectedClassName,
                            selectedSectionName: _selectedSectionName,
                            canLoad: _canLoad,
                            onPickDate: _pickDate,
                            onSessionChanged: (i) => setState(() => _selectedSession = i),
                            onShowSchoolPicker: _showSchoolPicker,
                            onShowClassPicker: _showClassPicker,
                            onShowSectionPicker: _showSectionPicker,
                            onLoadRoster: _loadRoster,
                          ),
                        if (_tabIndex == 1) LeaveManagementWidget(key: ValueKey(_refreshKey)),
                        if (_tabIndex == 2) ExportSheetWidget(
                          schools: _schools,
                          classes: _classes,
                          sections: _sections,
                        ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _tabIndex == 1
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
}
