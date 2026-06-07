import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelMarksParser {
  static String normalizeRollNo(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    return s;
  }

  static Map<String, dynamic>? _findSubjectByName(List<Map<String, dynamic>> subjects, String keyword) {
    final kw = keyword.toLowerCase();
    for (final s in subjects) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      if (name.contains(kw)) return s;
    }
    return null;
  }

  static String _getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    
    if (val is TextCellValue) return val.value.toString();
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) return val.value.toString();
    if (val is BoolCellValue) return val.value.toString();
    
    return val.toString();
  }

  
  static Map<String, dynamic> parseExcelMarks({
    required Uint8List fileBytes,
    required Map<String, String> columnMapping,
    required Map<String, dynamic> exam,
    required List<Map<String, dynamic>> subjects,
    required List<Map<String, dynamic>> students,
  }) {
    // 1. Column Mapping Validation
    bool hasAtLeastOneMapping = false;
    for (final val in columnMapping.values) {
      if (val.isNotEmpty) hasAtLeastOneMapping = true;
    }

    if (!hasAtLeastOneMapping) {
      throw Exception(
        'Excel column mapping does not match the selected exam series. Map at least one column.',
      );
    }

    // For NEET series validation
    final seriesName = exam['series']?['name']?.toString() ?? '';
    final isNeet = seriesName.toUpperCase().contains('NEET');
    if (isNeet) {
      final bioId =
          _findSubjectByName(subjects, 'biology')?['id'] ??
          _findSubjectByName(subjects, 'botany')?['id'] ??
          _findSubjectByName(subjects, 'zoology')?['id'] ??
          '';
      if (bioId.isNotEmpty) {
        final mapsBioTwice =
            columnMapping['M'] == bioId && columnMapping['N'] == bioId;
        if (!mapsBioTwice) {
          throw Exception(
            'For NEET, map four Excel columns to Physics, Chemistry, and Biology twice (Botany and Zoology)...',
          );
        }
      }
    }

    // 2. File Reading
    final excel = Excel.decodeBytes(fileBytes);
    if (excel.tables.isEmpty) {
      throw Exception('No worksheet found in the uploaded file');
    }

    final sheetName = excel.tables.keys.first;
    final sheet = excel[sheetName];
    if (sheet.maxRows == 0) {
      throw Exception('No worksheet found in the uploaded file');
    }

    // 3. Header Validation
    final headerRow = sheet.rows[0];
    if (headerRow.length <= 2) {
      throw Exception('Column C header must be Roll No');
    }

    // UPDATED: Using _getCellValue
    final colCValue = _getCellValue(headerRow[2]).trim().toLowerCase();
    if (!colCValue.contains('roll no') && !colCValue.contains('rollno')) {
      throw Exception('Column C header must be Roll No');
    }

    final colIndices = {'K': 10, 'L': 11, 'M': 12, 'N': 13};
    for (final entry in columnMapping.entries) {
      final colLetter = entry.key;
      final subjectId = entry.value;
      if (subjectId.isNotEmpty) {
        final colIdx = colIndices[colLetter]!;
        if (headerRow.length <= colIdx ||
            headerRow[colIdx] == null ||
            headerRow[colIdx]!.value == null ||
            _getCellValue(headerRow[colIdx]).trim().isEmpty) { // UPDATED
          throw Exception('Expected score headers in column $colLetter');
        }
      }
    }

    // 4. Data Extraction & Validate Marks Ranges
    final List<Map<String, dynamic>> parsedMarks = [];
    final List<Map<String, dynamic>> extraRows = [];
    final List<Map<String, dynamic>> missingRows = [];
    final Set<String> parsedRollNos = {};

    // final mapped student marks data to apply back
    // studentId -> subjectId -> marks
    final Map<String, Map<String, String>> pendingStudentMarks = {};

    for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.rows[rowIndex];
      if (row.length <= 2) continue; // Skip empty rows

      // UPDATED: Using _getCellValue
      final rollNoRaw = _getCellValue(row[2]);
      if (rollNoRaw.trim().isEmpty) continue;

      final rollNo = normalizeRollNo(rollNoRaw);
      parsedRollNos.add(rollNo);
      
      // UPDATED: Using _getCellValue
      final nameInExcel = row.length > 1 ? _getCellValue(row[1]) : '';

      // Match student
      final student = students.firstWhere(
        (s) => normalizeRollNo(s['roll_no']?.toString()) == rollNo,
        orElse: () => {},
      );

      if (student.isEmpty) {
        extraRows.add({
          'rowNumber': rowIndex + 1,
          'rollNo': rollNo,
          'name': nameInExcel,
        });
        continue;
      }

      final studentId = student['id'] as String;
      pendingStudentMarks[studentId] = {};
      final Map<String, String> studentMarksMap = {};

      // Gather column marks by subjectId
      final Map<String, List<double>> subjectValues = {};

      for (final entry in columnMapping.entries) {
        final colLetter = entry.key;
        final subjectId = entry.value;
        if (subjectId.isEmpty) continue;

        final colIdx = colIndices[colLetter]!;
        if (row.length <= colIdx) continue;

        // UPDATED: Using _getCellValue
        final cellVal = _getCellValue(row[colIdx]).trim();
        if (cellVal.isEmpty) continue;

        final numericVal = double.tryParse(cellVal);
        if (numericVal == null || !numericVal.isFinite) {
          throw Exception('Invalid marks found for roll no $rollNo');
        }

        final subject = subjects.firstWhere(
          (sub) => sub['id'] == subjectId,
          orElse: () => {},
        );
        if (subject.isNotEmpty) {
          final maxMarks = (subject['max_marks'] as num? ?? 100).toDouble();
          final subjectName = subject['name'] ?? 'Subject';

          if (numericVal < -90) {
            throw Exception(
              '$subjectName marks for roll no $rollNo cannot be below -90',
            );
          }

          if (numericVal > maxMarks) {
            throw Exception(
              '$subjectName marks for roll no $rollNo exceed full marks ($maxMarks)',
            );
          }

          subjectValues.putIfAbsent(subjectId, () => []).add(numericVal);
        }
      }

      // Compute final marks
      for (final sub in subjects) {
        final subId = sub['id'] as String;
        final maxMarks = (sub['max_marks'] as num? ?? 100).toDouble();
        final subName = sub['name'] ?? 'Subject';

        final vals = subjectValues[subId] ?? [];
        if (vals.isEmpty) continue;

        double totalVal = 0;
        for (final v in vals) {
          totalVal += v;
        }

        if (totalVal > maxMarks) {
          throw Exception(
            '$subName total marks ($totalVal) for roll no $rollNo exceed full marks ($maxMarks)',
          );
        }

        final String displayMark =
            (totalVal % 1 == 0)
                ? totalVal.toInt().toString()
                : totalVal.toString();
        studentMarksMap[subId] = displayMark;
        pendingStudentMarks[studentId]![subId] = displayMark;
      }

      parsedMarks.add({
        'rollNo': rollNo,
        'name': student['name'] ?? '',
        'marks': studentMarksMap,
      });
    }

    if (parsedMarks.isEmpty) {
      throw Exception('No uploaded roll numbers matched this student list');
    }

    // Identify missing students
    for (final student in students) {
      final rollNo = normalizeRollNo(student['roll_no']?.toString());
      if (!parsedRollNos.contains(rollNo)) {
        missingRows.add({'rollNo': rollNo, 'name': student['name'] ?? ''});
      }
    }

    return {
      'requiredRows': students.length,
      'derivedRows': parsedMarks.length,
      'missingRows': missingRows,
      'extraRows': extraRows,
      'parsedMarks': parsedMarks,
      'pendingStudentMarks': pendingStudentMarks,
    };
  }
}