import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:excel_plus/excel_plus.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import '../graphql/queries.dart';
import '../auth/auth_service.dart';
import '../services/exam_lookup_cache.dart';
import '../utils/exam_html_generator.dart';
import '../../widgets/arms_snackbar.dart';

class ExamExcelGenerator {
  static String _parseMeta(dynamic val, String type) {
    if (val == null) return 'All';
    final str = val.toString().trim();
    if (str.isEmpty || str == '[]' || str == 'null') return 'All';

    final clean = str
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", "")
        .trim();
    if (clean.isEmpty) return 'All';

    final parts = clean
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'All';

    final resolvedNames = <String>[];
    for (final part in parts) {
      final isUuid = part.contains('-') && part.length > 15;
      if (isUuid) {
        resolvedNames.add(ExamLookupCache.resolve(part, type));
      } else {
        resolvedNames.add(part);
      }
    }

    return resolvedNames.join(', ');
  }

  static Future<void> handleGenerateExcel({
    required BuildContext context,
    required Map<String, dynamic> exam,
    required ExamReportPreferences prefs,
    required BuildContext bottomSheetContext,
  }) async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        throw Exception('Organization not found. Please log in again.');
      }

      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExamDetails),
          variables: {'examId': exam['id'], 'organisationId': orgId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final details = result.data?['getExamDetails'] as Map<String, dynamic>?;
      if (details == null) {
        throw Exception('No exam details found.');
      }

      final examData = details['exam'] as Map<String, dynamic>?;
      final rawMarks = (details['marks'] as List? ?? []).cast<Map<String, dynamic>>();
      final students = (details['students'] as List? ?? []).cast<Map<String, dynamic>>();
      final subjectsData = (details['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

      final className = _parseMeta(examData?['for_class'], 'class');
      final sectionName = _parseMeta(examData?['for_section'], 'section');
      final classSec = '$className-$sectionName';

      final List<SubjectColumn> subjects = subjectsData.map((sub) {
        return SubjectColumn(
          key: sub['id']?.toString() ?? '',
          label: sub['name']?.toString() ?? '',
          maxMarks: (sub['max_marks'] as num?)?.toInt() ?? 100,
        );
      }).toList();

      final studentMarksGrouped = <String, List<Map<String, dynamic>>>{};
      for (final m in rawMarks) {
        final sId = m['student_id']?.toString() ?? '';
        if (sId.isNotEmpty) {
          studentMarksGrouped.putIfAbsent(sId, () => []).add(m);
        }
      }

      final List<_TempStudentInfo> tempStudents = [];

      for (final student in students) {
        final sId = student['id']?.toString() ?? '';
        final studentMarks = studentMarksGrouped[sId] ?? [];
        final Map<String, double> subjectMarksMap = {};

        double totalObtained = 0.0;
        bool allAbsent = studentMarks.isNotEmpty;

        for (final m in studentMarks) {
          final isAbsent = m['is_absent'] == true;
          final subId = m['subject_id']?.toString() ?? '';
          if (subId.isNotEmpty) {
            if (isAbsent) {
              subjectMarksMap[subId] = -1.0;
            } else {
              allAbsent = false;
              final marksObtained = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
              subjectMarksMap[subId] = marksObtained;
              totalObtained += marksObtained;
            }
          }
        }

        tempStudents.add(
          _TempStudentInfo(
            id: sId,
            name: student['name']?.toString() ?? '',
            rollNo: student['roll_no']?.toString() ?? '',
            marks: subjectMarksMap,
            total: totalObtained,
            isAbsent: studentMarks.isEmpty ? false : allAbsent,
          ),
        );
      }

      tempStudents.sort((a, b) {
        if (a.isAbsent && b.isAbsent) return 0;
        if (a.isAbsent) return 1;
        if (b.isAbsent) return -1;
        return b.total.compareTo(a.total);
      });

      final excel = Excel.createExcel();
      final sheet = excel['Exam Report'];
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final examName = examData?['name']?.toString() ?? exam['name']?.toString() ?? 'Exam Report';
      
      final rawDate = examData?['exam_date']?.toString() ?? exam['exam_date']?.toString();
      String examDateString = 'N/A';
      if (rawDate != null && rawDate.isNotEmpty) {
        try {
          final date = DateTime.parse(rawDate);
          final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
          final day = date.day.toString().padLeft(2, '0');
          final month = months[date.month - 1];
          final year = date.year.toString().substring(2);
          examDateString = '$day-$month-$year';
        } catch (_) {}
      }

      final headerStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);

      final int startCol = 4;
      final int endCol = 4 + subjects.length - 1;
      if (endCol >= startCol) {
        final titleStart = CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 0);
        final titleEnd = CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: 0);
        sheet.merge(titleStart, titleEnd, customValue: TextCellValue(examName));
        sheet.cell(titleStart).cellStyle = headerStyle;

        final dateStart = CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 1);
        final dateEnd = CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: 1);
        sheet.merge(dateStart, dateEnd, customValue: TextCellValue(examDateString));
        sheet.cell(dateStart).cellStyle = headerStyle;
      }

      final List<String> headers = ['Sl', 'Roll', 'Student', 'Class'];
      for (var sub in subjects) {
        final label = sub.label.isNotEmpty ? '${sub.label} (${sub.maxMarks})' : '';
        headers.add(label);
      }

      final totalMaxMarks = subjects.fold<int>(0, (sum, sub) => sum + sub.maxMarks);

      if (subjects.length > 1) {
        headers.add('Total ($totalMaxMarks)');
      }
      headers.add('Total ($totalMaxMarks)');
      headers.add('%');
      headers.add('Rank');

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3), TextCellValue('Average'));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).cellStyle = CellStyle(bold: true);

      final Map<String, double> subjectAverages = {};
      for (var sub in subjects) {
        double subSum = 0;
        int subPresentCount = 0;
        for (var student in tempStudents) {
          final mark = student.marks[sub.key];
          if (mark != null && mark >= 0) {
            subSum += mark;
            subPresentCount++;
          }
        }
        subjectAverages[sub.key] = subPresentCount > 0 ? (subSum / subPresentCount) : 0.0;
      }

      double totalSum = 0;
      int totalPresentCount = 0;
      for (var student in tempStudents) {
        if (!student.isAbsent) {
          totalSum += student.total;
          totalPresentCount++;
        }
      }
      final double overallAverage = totalPresentCount > 0 ? (totalSum / totalPresentCount) : 0.0;

      int colIdx = 4;
      for (var sub in subjects) {
        final avg = subjectAverages[sub.key] ?? 0.0;
        final cellVal = avg % 1 == 0 ? IntCellValue(avg.toInt()) : DoubleCellValue(double.parse(avg.toStringAsFixed(2)));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: 3), cellVal);
      }

      if (subjects.length > 1) {
        final cellVal = overallAverage % 1 == 0 ? IntCellValue(overallAverage.toInt()) : DoubleCellValue(double.parse(overallAverage.toStringAsFixed(2)));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: 3), cellVal);
      }

      {
        final cellVal = overallAverage % 1 == 0 ? IntCellValue(overallAverage.toInt()) : DoubleCellValue(double.parse(overallAverage.toStringAsFixed(2)));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: 3), cellVal);
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3)).cellStyle = CellStyle(bold: true);
      }

      for (int i = 0; i < tempStudents.length; i++) {
        final student = tempStudents[i];
        final rowIndex = 4 + i;

        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex), IntCellValue(i + 1));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex), TextCellValue(student.rollNo));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex), TextCellValue(student.name));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex), TextCellValue(classSec));

        int colOffset = 4;
        for (var sub in subjects) {
          final mark = student.marks[sub.key];
          if (student.isAbsent || mark == null || mark < 0) {
            sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), TextCellValue('AB'));
          } else {
            sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), IntCellValue(mark.toInt()));
          }
        }

        if (subjects.length > 1) {
          if (student.isAbsent) {
            sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), TextCellValue('AB'));
          } else {
            sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), IntCellValue(student.total.toInt()));
          }
        }

        if (student.isAbsent) {
          sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), TextCellValue('-'));
          sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), TextCellValue('-'));
          sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), TextCellValue('-'));
        } else {
          sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), IntCellValue(student.total.toInt()));
          final double pct = totalMaxMarks > 0 ? (student.total / totalMaxMarks) * 100 : 0.0;
          sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), TextCellValue('${pct.toStringAsFixed(2)}%'));
          sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colOffset++, rowIndex: rowIndex), IntCellValue(i + 1));
        }
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file.');
      }

      final sanitizedExamName = examName
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      
      final fileName = '${sanitizedExamName}_Report.xlsx';

      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }

      final String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Exam Excel Report',
        fileName: fileName,
        bytes: Uint8List.fromList(fileBytes),
      );

      if (outputFile != null && context.mounted) {
        ArmsSnackbar.showSuccess(context, 'Excel report saved successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        ArmsSnackbar.showError(context, 'Failed to generate Excel: $e');
      }
    }
  }
}

class _TempStudentInfo {
  final String id;
  final String name;
  final String rollNo;
  final Map<String, double> marks;
  final double total;
  final bool isAbsent;

  _TempStudentInfo({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.marks,
    required this.total,
    required this.isAbsent,
  });
}
