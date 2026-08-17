import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'attendance_report_service.dart';

class EvalBeeCsvGenerator {
  static String _escapeCsvCell(dynamic value) {
    final text = (value ?? '').toString();
    if (text.contains('"') || text.contains(',') || text.contains('\n') || text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String generateCsv(PreparedAttendanceData preparedData) {
    final rows = <List<String>>[
      ['ROLLNO', 'NAME', 'CLASS', 'EMAILID', 'PHONENO'],
    ];

    for (final row in preparedData.parsedRows) {
      final rollNo = (row.rollNo ?? '').toString();
      final name = row.studentName;
      final classSection = [row.className, row.sectionName]
          .where((s) => s.isNotEmpty)
          .join(' - ');

      rows.add([
        rollNo,
        name,
        classSection,
        '', // EMAILID
        '', // PHONENO
      ]);
    }

    return rows.map((r) => r.map(_escapeCsvCell).join(',')).join('\r\n');
  }

  static Future<String?> exportEvalBeeCsv({
    required PreparedAttendanceData preparedData,
    required String fileName,
  }) async {
    final csvContent = generateCsv(preparedData);
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    return await FilePicker.saveFile(
      dialogTitle: 'Save EvalBee CSV Report',
      fileName: fileName,
      bytes: bytes,
    );
  }
}
