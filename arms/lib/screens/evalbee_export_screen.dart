import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../core/graphql/queries.dart';
import '../core/auth/auth_service.dart';
import '../core/utils/attendance_html_generator.dart';
import '../widgets/arms_top_app_bar.dart';
import '../widgets/arms_dropdown_selector.dart';
import '../widgets/arms_snackbar.dart';
import 'attendance/widgets/export_handlers.dart';

class EvalBeeExportScreen extends StatefulWidget {
  const EvalBeeExportScreen({super.key});

  @override
  State<EvalBeeExportScreen> createState() => _EvalBeeExportScreenState();
}

class _EvalBeeExportScreenState extends State<EvalBeeExportScreen> {
  bool _isLoadingLookups = true;
  String? _lookupError;
  bool _hasFetched = false;

  List<dynamic> _schools = [];
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];

  String? _selectedSchoolId;
  String? _selectedSchoolName = 'All schools';
  String? _selectedClassId;
  String? _selectedClassName = 'All classes';
  String? _selectedSectionId;
  String? _selectedSectionName = 'All sections';

  final TextEditingController _classOverrideController =
      TextEditingController();
  bool _isExporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFetched) {
      _hasFetched = true;
      _fetchLookups();
    }
  }

  @override
  void dispose() {
    _classOverrideController.dispose();
    super.dispose();
  }

  Future<void> _fetchLookups() async {
    final admin = AuthService.currentAdmin;
    final orgId = admin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'No organization associated with this account.';
      });
      return;
    }

    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      debugPrint(
        '[EvalBeeExportScreen] Querying getLookups with orgId: $orgId',
      );
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getLookups),
          variables: {'organisationId': orgId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      debugPrint(
        '[EvalBeeExportScreen] result.hasException: ${result.hasException}',
      );
      debugPrint('[EvalBeeExportScreen] result.exception: ${result.exception}');
      debugPrint('[EvalBeeExportScreen] result.data: ${result.data}');

      if (result.hasException) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = result.exception.toString();
        });
        return;
      }

      final data = result.data?['getLookups'];
      if (data != null) {
        setState(() {
          _schools = data['schools'] ?? [];
          _classes = data['classes'] ?? [];
          _sections = data['sections'] ?? [];
          _isLoadingLookups = false;
        });
      } else {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'Failed to load organization data.';
        });
      }
    } catch (e) {
      debugPrint('[EvalBeeExportScreen] Error fetching lookups: $e');
      setState(() {
        _isLoadingLookups = false;
        _lookupError = e.toString();
      });
    }
  }

  void _showPicker(
    String title,
    List<Map<String, dynamic>> items,
    String? selectedId,
    Function(String?, String) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.roundSixteen),
        ),
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
                    color: AppColors.outlineMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTextStyles.headerSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children:
                        items
                            .map(
                              (item) => ListTile(
                                title: Text(
                                  item['name'],
                                  style: AppTextStyles.bodyMedium,
                                ),
                                trailing:
                                    selectedId == item['id']
                                        ? const Icon(
                                          Icons.check,
                                          color: AppColors.primary,
                                        )
                                        : null,
                                onTap: () {
                                  onSelected(item['id'], item['name']);
                                  Navigator.pop(ctx);
                                },
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _exportEvalBeeCsv() async {
    final admin = AuthService.currentAdmin;
    final orgId = admin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      ArmsSnackbar.showError(context, 'No organization details found.');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final config = AttendanceExportConfig(
        fromDate: DateTime.now(),
        toDate: DateTime.now(),
        reportType: 'EvalBee Roster',
        session: AttendanceSession.morningIn,
        mode: AttendanceSheetMode.sessionWise,
        selectedSchoolId: _selectedSchoolId,
        selectedSchoolName: _selectedSchoolName,
        selectedClassId: _selectedClassId,
        selectedClassName: _selectedClassName,
        selectedSectionId: _selectedSectionId,
        selectedSectionName: _selectedSectionName,
        customClassOverride: _classOverrideController.text,
      );

      await AttendanceExportHandler.exportEvalBeeCsv(
        context: context,
        orgId: orgId,
        config: config,
      );

      if (mounted) {
        ArmsSnackbar.showSuccess(
          context,
          'EvalBee CSV report exported successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'EvalBee CSV export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(title: 'EvalBee CSV Export'),
      body:
          _isLoadingLookups
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : _lookupError != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _lookupError!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.errorText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLookups,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.marginPage),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters & Configuration',
                      style: AppTextStyles.headerSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // School Selector
                    ArmsDropdownSelector(
                      label: 'School',
                      value: _selectedSchoolName ?? 'All schools',
                      icon: Icons.account_balance_outlined,
                      onTap: () {
                        final items = <Map<String, dynamic>>[
                          {'id': null, 'name': 'All schools'},
                          ..._schools.map(
                            (s) => {
                              'id': s['id']?.toString(),
                              'name': s['name']?.toString() ?? '',
                            },
                          ),
                        ];
                        _showPicker('Select School', items, _selectedSchoolId, (
                          id,
                          name,
                        ) {
                          setState(() {
                            _selectedSchoolId = id;
                            _selectedSchoolName = name;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Class Selector
                    ArmsDropdownSelector(
                      label: 'Class',
                      value: _selectedClassName ?? 'All classes',
                      icon: Icons.class_outlined,
                      onTap: () {
                        final items = <Map<String, dynamic>>[
                          {'id': null, 'name': 'All classes'},
                          ..._classes.map(
                            (c) => {
                              'id': c['id']?.toString(),
                              'name': c['name']?.toString() ?? '',
                            },
                          ),
                        ];
                        _showPicker('Select Class', items, _selectedClassId, (
                          id,
                          name,
                        ) {
                          setState(() {
                            _selectedClassId = id;
                            _selectedClassName = name;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Section Selector
                    ArmsDropdownSelector(
                      label: 'Section',
                      value: _selectedSectionName ?? 'All sections',
                      icon: Icons.grid_view_outlined,
                      onTap: () {
                        final items = <Map<String, dynamic>>[
                          {'id': null, 'name': 'All sections'},
                          ..._sections.map(
                            (sec) => {
                              'id': sec['id']?.toString(),
                              'name': sec['name']?.toString() ?? '',
                            },
                          ),
                        ];
                        _showPicker(
                          'Select Section',
                          items,
                          _selectedSectionId,
                          (id, name) {
                            setState(() {
                              _selectedSectionId = id;
                              _selectedSectionName = name;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Custom CLASS Column Override Input Field
                    const SizedBox(height: 12),
                    TextField(
                      controller: _classOverrideController,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMain,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Custom Class Field (Optional)',

                        prefixIcon: const Icon(
                          Icons.edit_note,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Export Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportEvalBeeCsv,
                        icon:
                            _isExporting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(
                                  Icons.download_outlined,
                                  color: Colors.white,
                                ),
                        label: Text(
                          _isExporting ? 'Exporting...' : 'Export',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
