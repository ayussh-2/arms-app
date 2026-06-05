import 'dart:typed_data';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_dropdown_selector.dart';
import '../../widgets/arms_snackbar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/attendance_html_generator.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/attendance_report_service.dart';
import '../../core/services/attendance_excel_generator.dart';
import 'widgets/export_options_card.dart';
import 'widgets/export_handlers.dart';

class ExportSheetWidget extends StatefulWidget {
  const ExportSheetWidget({
    super.key,
    required this.schools,
    required this.classes,
    required this.sections,
  });

  final List<dynamic> schools;
  final List<dynamic> classes;
  final List<dynamic> sections;

  @override
  State<ExportSheetWidget> createState() => _ExportSheetWidgetState();
}

class _ExportSheetWidgetState extends State<ExportSheetWidget> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _reportType = 'Absent + Present';
  AttendanceSession _session = AttendanceSession.morningIn;
  AttendanceSheetMode _mode = AttendanceSheetMode.combineByDay;

  String? _selectedSchoolId;
  String? _selectedSchoolName = 'All schools';
  String? _selectedClassId;
  String? _selectedClassName = 'All classes';
  String? _selectedSectionId;
  String? _selectedSectionName = 'All sections';

  bool _includeStudentPic = false;
  bool _showRollNo = true;
  bool _showSchool = true;
  bool _showClassSection = true;
  bool _isShortStatus = true;
  bool _coloredStatus = true;
  bool _isLightTheme = true;
  bool _showHolidays = true;
  bool _showSundays = true;
  bool _removeBlankRows = false;
  bool _showRemarks = false;
  bool _hideUnmarkedDays = true;
  bool _datesDescending = true;

  bool _isExporting = false;

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _fromDate : _toDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  void _showBottomSheetPicker(String title, List<Map<String, dynamic>> items, String? selectedId, Function(String?, String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.roundSixteen))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineMedium, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: items.map((item) => ListTile(
                  title: Text(item['name'], style: AppTextStyles.bodyMedium),
                  trailing: selectedId == item['id'] ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    onSelected(item['id'], item['name']);
                    Navigator.pop(ctx);
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AttendanceExportConfig _buildConfig() {
    return AttendanceExportConfig(
      fromDate: _fromDate,
      toDate: _toDate,
      reportType: _reportType,
      session: _session,
      mode: _mode,
      selectedSchoolId: _selectedSchoolId,
      selectedSchoolName: _selectedSchoolName,
      selectedClassId: _selectedClassId,
      selectedClassName: _selectedClassName,
      selectedSectionId: _selectedSectionId,
      selectedSectionName: _selectedSectionName,
      includeStudentPic: _includeStudentPic,
      showRollNo: _showRollNo,
      showSchool: _showSchool,
      showClassSection: _showClassSection,
      isShortStatus: _isShortStatus,
      coloredStatus: _coloredStatus,
      isLightTheme: _isLightTheme,
      showHolidays: _showHolidays,
      showSundays: _showSundays,
      removeBlankRows: _removeBlankRows,
      showRemarks: _showRemarks,
      hideUnmarkedDays: _hideUnmarkedDays,
      datesDescending: _datesDescending,
    );
  }

  Future<void> _exportPdfReport() async {
    final orgId = AuthService.currentAdmin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      ArmsSnackbar.showError(context, 'No organization associated with this account.');
      return;
    }
    setState(() => _isExporting = true);
    try {
      await AttendanceExportHandler.exportPdf(
        context: context,
        orgId: orgId,
        config: _buildConfig(),
      );
      if (mounted) {
        ArmsSnackbar.showSuccess(context, 'PDF report generated successfully.');
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcelReport() async {
    final orgId = AuthService.currentAdmin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      ArmsSnackbar.showError(context, 'No organization associated with this account.');
      return;
    }
    setState(() => _isExporting = true);
    try {
      await AttendanceExportHandler.exportExcel(
        context: context,
        orgId: orgId,
        config: _buildConfig(),
      );
      if (mounted) {
        ArmsSnackbar.showSuccess(context, 'Excel report exported successfully.');
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Excel export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArmsDropdownSelector(label: 'From Date', value: _formatDate(_fromDate), icon: Icons.calendar_today_outlined, onTap: () => _pickDate(true)),
        const SizedBox(height: 16),
        ArmsDropdownSelector(label: 'To Date', value: _formatDate(_toDate), icon: Icons.calendar_today_outlined, onTap: () => _pickDate(false)),
        const SizedBox(height: 16),
        ArmsDropdownSelector(
          label: 'Report Type',
          value: _reportType,
          icon: Icons.assignment_outlined,
          onTap: () => _showBottomSheetPicker(
            'Select Report Type',
            ['Absent + Present', 'Only Absentees', 'Only Present'].map((o) => {'id': o, 'name': o}).toList(),
            _reportType,
            (_, name) => setState(() => _reportType = name),
          ),
        ),
        const SizedBox(height: 16),
        ArmsDropdownSelector(
          label: 'Session',
          value: _session == AttendanceSession.morningIn ? 'Morning In' : _session == AttendanceSession.morningOut ? 'Morning Out' : _session == AttendanceSession.eveningIn ? 'Evening In' : 'Evening Out',
          icon: Icons.access_time_outlined,
          onTap: () => _showBottomSheetPicker(
            'Select Session',
            AttendanceSession.values.map((s) => {
              'id': s.name,
              'name': s == AttendanceSession.morningIn ? 'Morning In' : s == AttendanceSession.morningOut ? 'Morning Out' : s == AttendanceSession.eveningIn ? 'Evening In' : 'Evening Out'
            }).toList(),
            _session.name,
            (id, _) => setState(() => _session = AttendanceSession.values.firstWhere((e) => e.name == id)),
          ),
        ),
        const SizedBox(height: 16),
        ArmsDropdownSelector(
          label: 'Mode',
          value: _mode == AttendanceSheetMode.sessionWise ? 'Session Wise' : 'Combine By Day',
          icon: Icons.grid_view_outlined,
          onTap: () => _showBottomSheetPicker(
            'Select Mode',
            AttendanceSheetMode.values.map((m) => {'id': m.name, 'name': m == AttendanceSheetMode.sessionWise ? 'Session Wise' : 'Combine By Day'}).toList(),
            _mode.name,
            (id, _) => setState(() => _mode = AttendanceSheetMode.values.firstWhere((e) => e.name == id)),
          ),
        ),
        const SizedBox(height: 16),
        ArmsDropdownSelector(
          label: 'School',
          value: _selectedSchoolName,
          icon: Icons.school_outlined,
          onTap: () => _showBottomSheetPicker(
            'Select School',
            [{'id': null, 'name': 'All schools'}, ...widget.schools.map((s) => {'id': s['id']?.toString(), 'name': s['name']?.toString() ?? ''})],
            _selectedSchoolId,
            (id, name) => setState(() {
              _selectedSchoolId = id;
              _selectedSchoolName = name;
            }),
          ),
        ),
        const SizedBox(height: 16),
        ArmsDropdownSelector(
          label: 'Class',
          value: _selectedClassName,
          icon: Icons.class_outlined,
          onTap: () => _showBottomSheetPicker(
            'Select Class',
            [{'id': null, 'name': 'All classes'}, ...widget.classes.map((c) => {'id': c['id']?.toString(), 'name': c['name']?.toString() ?? ''})],
            _selectedClassId,
            (id, name) => setState(() {
              _selectedClassId = id;
              _selectedClassName = name;
            }),
          ),
        ),
        const SizedBox(height: 16),
        ArmsDropdownSelector(
          label: 'Section',
          value: _selectedSectionName,
          icon: Icons.splitscreen_outlined,
          onTap: () => _showBottomSheetPicker(
            'Select Section',
            [{'id': null, 'name': 'All sections'}, ...widget.sections.map((s) => {'id': s['id']?.toString(), 'name': s['name']?.toString() ?? ''})],
            _selectedSectionId,
            (id, name) => setState(() {
              _selectedSectionId = id;
              _selectedSectionName = name;
            }),
          ),
        ),
        const SizedBox(height: 24),
        ExportOptionsCard(
          includeStudentPic: _includeStudentPic,
          showRollNo: _showRollNo,
          showSchool: _showSchool,
          showClassSection: _showClassSection,
          isShortStatus: _isShortStatus,
          coloredStatus: _coloredStatus,
          isLightTheme: _isLightTheme,
          showHolidays: _showHolidays,
          showSundays: _showSundays,
          removeBlankRows: _removeBlankRows,
          showRemarks: _showRemarks,
          hideUnmarkedDays: _hideUnmarkedDays,
          datesDescending: _datesDescending,
          onIncludeStudentPicChanged: (v) => setState(() => _includeStudentPic = v),
          onShowRollNoChanged: (v) => setState(() => _showRollNo = v),
          onShowSchoolChanged: (v) => setState(() => _showSchool = v),
          onShowClassSectionChanged: (v) => setState(() => _showClassSection = v),
          onIsShortStatusChanged: (v) => setState(() => _isShortStatus = v),
          onColoredStatusChanged: (v) => setState(() => _coloredStatus = v),
          onIsLightThemeChanged: (v) => setState(() => _isLightTheme = v),
          onShowHolidaysChanged: (v) => setState(() => _showHolidays = v),
          onShowSundaysChanged: (v) => setState(() => _showSundays = v),
          onRemoveBlankRowsChanged: (v) => setState(() => _removeBlankRows = v),
          onShowRemarksChanged: (v) => setState(() => _showRemarks = v),
          onHideUnmarkedDaysChanged: (v) => setState(() => _hideUnmarkedDays = v),
          onDatesDescendingChanged: (v) => setState(() => _datesDescending = v),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportPdfReport,
                  icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  label: Text('Export PDF', style: AppTextStyles.headerSmall.copyWith(color: AppColors.onPrimary, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportExcelReport,
                  icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.table_chart_outlined, size: 20),
                  label: Text('Export Excel', style: AppTextStyles.headerSmall.copyWith(color: AppColors.onPrimary, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
