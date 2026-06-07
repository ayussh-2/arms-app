import 'package:excel/excel.dart' hide Border;
import '../utils/attendance_html_generator.dart';
import 'attendance_report_service.dart';

class AttendanceExcelGenerator {
  static List<int>? generateExcel({
    required PreparedAttendanceData preparedData,
    required bool showRollNo,
    required bool showSchool,
    required bool showClassSection,
    required bool showRemarks,
    required bool isShortStatus,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final List<String> columns = [];
    columns.add('Sl. No.');
    if (showRollNo) columns.add('Roll No.');
    columns.add('Student');
    if (showSchool) columns.add('School');
    if (showClassSection) columns.add('Std');
    columns.add('Summary');

    final int datesStartIndex = columns.length;
    final headerStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);


    for (int c = 0; c < datesStartIndex; c++) {
      final cStart = CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0);
      final cEnd = CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1);
      sheet.merge(cStart, cEnd, customValue: TextCellValue(columns[c]));
      sheet.cell(cStart).cellStyle = headerStyle;
    }

    for (int dIdx = 0; dIdx < preparedData.dateColumns.length; dIdx++) {
      final colIdx = datesStartIndex + dIdx;
      final parts = preparedData.dateColumns[dIdx].split('-');
      final dayLabel = parts.length == 3 ? parts[2] : preparedData.dateColumns[dIdx];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: 1));
      cell.value = TextCellValue(dayLabel);
      cell.cellStyle = headerStyle;
    }

    int currentOffset = datesStartIndex;
    for (final group in preparedData.monthYearGroups) {
      final int groupSize = group.dates.length;
      if (groupSize > 0) {
        final cStart = CellIndex.indexByColumnRow(columnIndex: currentOffset, rowIndex: 0);
        final cEnd = CellIndex.indexByColumnRow(columnIndex: currentOffset + groupSize - 1, rowIndex: 0);
        sheet.merge(cStart, cEnd, customValue: TextCellValue(group.label));
        sheet.cell(cStart).cellStyle = headerStyle;
      }
      currentOffset += groupSize;
    }

    if (showRemarks) {
      final int remarksCol = datesStartIndex + preparedData.dateColumns.length;
      final cStart = CellIndex.indexByColumnRow(columnIndex: remarksCol, rowIndex: 0);
      final cEnd = CellIndex.indexByColumnRow(columnIndex: remarksCol, rowIndex: 1);
      sheet.merge(cStart, cEnd, customValue: TextCellValue('Remarks'));
      sheet.cell(cStart).cellStyle = headerStyle;
    }

    for (int i = 0; i < preparedData.parsedRows.length; i++) {
      final row = preparedData.parsedRows[i];
      final int rowIdx = 2 + i;
      int colIdx = 0;

      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIdx), IntCellValue(i + 1));
      if (showRollNo) {
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIdx), row.rollNo != null ? IntCellValue(row.rollNo!) : TextCellValue('-'));
      }
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIdx), TextCellValue(row.studentName));
      if (showSchool) {
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIdx), TextCellValue(row.schoolName));
      }
      if (showClassSection) {
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIdx), TextCellValue('${row.className}${row.sectionName.isNotEmpty ? ' - ${row.sectionName}' : ''}'));
      }
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIdx), TextCellValue(row.summary));

      for (int dIdx = 0; dIdx < preparedData.dateColumns.length; dIdx++) {
        final date = preparedData.dateColumns[dIdx];
        final holidayName = row.holidayByDate[date];
        CellValue cellVal;
        if (holidayName != null) {
          cellVal = TextCellValue(holidayName.toUpperCase());
        } else {
          final isSunday = DateTime.parse(date).weekday == DateTime.sunday;
          if (isSunday) {
            cellVal = TextCellValue('SUNDAY');
          } else {
            cellVal = TextCellValue(getStatusChar(row.statusesByDate[date]));
          }
        }
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: datesStartIndex + dIdx, rowIndex: rowIdx), cellVal);
      }

      if (showRemarks) {
        final int remarksCol = datesStartIndex + preparedData.dateColumns.length;
        final remarkStrings = <String>[];
        for (var date in preparedData.dateColumns) {
          if (row.remarksByDate[date] != null && row.remarksByDate[date]!.isNotEmpty) {
            remarkStrings.add("$date: ${row.remarksByDate[date]!}");
          }
        }
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: remarksCol, rowIndex: rowIdx), TextCellValue(remarkStrings.isEmpty ? "-" : remarkStrings.join(" | ")));
      }
    }

    return excel.save();
  }

  static String getStatusChar(AttendanceStatus? status) {
    if (status == null) return "-";
    switch (status) {
      case AttendanceStatus.present: return "P";
      case AttendanceStatus.leave: return "L";
      case AttendanceStatus.na: return "N";
      case AttendanceStatus.absent: return "A";
    }
  }
}
