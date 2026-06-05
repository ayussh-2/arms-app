import 'dart:typed_data';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../widgets/arms_snackbar.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/attendance_html_generator.dart';
import '../../../core/services/attendance_report_service.dart';
import '../../../core/services/attendance_excel_generator.dart';

class AttendanceExportConfig {
  final DateTime fromDate;
  final DateTime toDate;
  final String reportType;
  final AttendanceSession session;
  final AttendanceSheetMode mode;
  final String? selectedSchoolId;
  final String? selectedSchoolName;
  final String? selectedClassId;
  final String? selectedClassName;
  final String? selectedSectionId;
  final String? selectedSectionName;
  final bool includeStudentPic;
  final bool showRollNo;
  final bool showSchool;
  final bool showClassSection;
  final bool isShortStatus;
  final bool coloredStatus;
  final bool isLightTheme;
  final bool showHolidays;
  final bool showSundays;
  final bool removeBlankRows;
  final bool showRemarks;
  final bool hideUnmarkedDays;
  final bool datesDescending;

  AttendanceExportConfig({
    required this.fromDate,
    required this.toDate,
    required this.reportType,
    required this.session,
    required this.mode,
    required this.selectedSchoolId,
    required this.selectedSchoolName,
    required this.selectedClassId,
    required this.selectedClassName,
    required this.selectedSectionId,
    required this.selectedSectionName,
    required this.includeStudentPic,
    required this.showRollNo,
    required this.showSchool,
    required this.showClassSection,
    required this.isShortStatus,
    required this.coloredStatus,
    required this.isLightTheme,
    required this.showHolidays,
    required this.showSundays,
    required this.removeBlankRows,
    required this.showRemarks,
    required this.hideUnmarkedDays,
    required this.datesDescending,
  });
}

class AttendanceExportHandler {
  static String _sanitizeName(String? val) {
    if (val == null) return '';
    return val
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static Future<void> exportPdf({
    required BuildContext context,
    required String orgId,
    required AttendanceExportConfig config,
  }) async {
    final client = GraphQLProvider.of(context).value;
    final preparedData = await AttendanceReportService.fetchAndPrepareData(
      client: client,
      organisationId: orgId,
      fromDate: config.fromDate,
      toDate: config.toDate,
      schoolId: config.selectedSchoolId,
      classId: config.selectedClassId,
      sectionId: config.selectedSectionId,
      showSundays: config.showSundays,
      datesDescending: config.datesDescending,
      hideUnmarkedDays: config.hideUnmarkedDays,
      includeStudentPic: config.includeStudentPic,
      reportType: config.reportType,
      removeBlankRows: config.removeBlankRows,
      showHolidays: config.showHolidays,
      session: config.session,
    );

    if (preparedData.parsedRows.isEmpty) {
      throw Exception('No matching records to export.');
    }

    final preferences = AttendanceTemplatePreferences(
      theme: config.isLightTheme ? ThemeMode.light : ThemeMode.dark,
      includeStudentPic: config.includeStudentPic,
      showRollNo: config.showRollNo,
      showSchool: config.showSchool,
      showClassSection: config.showClassSection,
      coloredStatus: config.coloredStatus,
      isShortStatus: config.isShortStatus,
      showRemarks: config.showRemarks,
      showHeader: true,
      showLogo: true,
      customHeaderText: "Attendance Report",
    );

    final generatedHtml = AttendanceHtmlGenerator.generateHtml(
      visibleRows: preparedData.parsedRows,
      dateColumns: preparedData.dateColumns,
      monthYearGroups: preparedData.monthYearGroups,
      preferences: preferences,
      sheetMode: config.mode,
      attendanceSessions: [config.session],
      orgLogoUrl: AppConstants.orgLogoUrl,
      orgHeaderUrl: AppConstants.orgHeaderUrl,
    );

    final pdfName = '${_sanitizeName(config.selectedSchoolName)}_${_sanitizeName(config.selectedClassName)}_${_sanitizeName(config.selectedSectionName)}_${DateFormat('yyyy-MM-dd').format(config.fromDate)}_to_${DateFormat('yyyy-MM-dd').format(config.toDate)}';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async =>
          await Printing.convertHtml(format: format, html: generatedHtml),
      name: pdfName,
    );
  }

  static Future<void> exportExcel({
    required BuildContext context,
    required String orgId,
    required AttendanceExportConfig config,
  }) async {
    final client = GraphQLProvider.of(context).value;
    final preparedData = await AttendanceReportService.fetchAndPrepareData(
      client: client,
      organisationId: orgId,
      fromDate: config.fromDate,
      toDate: config.toDate,
      schoolId: config.selectedSchoolId,
      classId: config.selectedClassId,
      sectionId: config.selectedSectionId,
      showSundays: config.showSundays,
      datesDescending: config.datesDescending,
      hideUnmarkedDays: config.hideUnmarkedDays,
      includeStudentPic: false,
      reportType: config.reportType,
      removeBlankRows: config.removeBlankRows,
      showHolidays: config.showHolidays,
      session: config.session,
    );

    if (preparedData.parsedRows.isEmpty) {
      throw Exception('No matching records to export.');
    }

    final fileBytes = AttendanceExcelGenerator.generateExcel(
      preparedData: preparedData,
      showRollNo: config.showRollNo,
      showSchool: config.showSchool,
      showClassSection: config.showClassSection,
      showRemarks: config.showRemarks,
      isShortStatus: config.isShortStatus,
    );

    if (fileBytes == null) throw Exception('Failed to generate Excel file.');

    final fileName = '${_sanitizeName(config.selectedSchoolName)}_${_sanitizeName(config.selectedClassName)}_${_sanitizeName(config.selectedSectionName)}_${DateFormat('yyyy-MM-dd').format(config.fromDate)}_to_${DateFormat('yyyy-MM-dd').format(config.toDate)}.xlsx';

    final String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Attendance Excel Report',
      fileName: fileName,
      bytes: Uint8List.fromList(fileBytes),
    );

    if (outputFile == null) {
      throw Exception('Save operation cancelled or failed.');
    }
  }
}
