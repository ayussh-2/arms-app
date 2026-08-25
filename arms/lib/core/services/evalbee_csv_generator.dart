import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../graphql/queries.dart';
import 'attendance_report_service.dart';

class EvalBeeStudentData {
  final int? rollNo;
  final String name;
  final String className;
  final String sectionName;

  EvalBeeStudentData({
    required this.rollNo,
    required this.name,
    required this.className,
    required this.sectionName,
  });
}

class EvalBeeCsvGenerator {
  static String _escapeCsvCell(dynamic value) {
    final text = (value ?? '').toString();
    if (text.contains('"') || text.contains(',') || text.contains('\n') || text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String generateCsvFromStudents(List<EvalBeeStudentData> students, {String? customClassOverride}) {
    final rows = <List<String>>[
      ['ROLLNO', 'NAME', 'CLASS', 'EMAILID', 'PHONENO'],
    ];

    for (final student in students) {
      final rollNo = (student.rollNo ?? '').toString();
      final name = student.name;
      final classSection = (customClassOverride != null && customClassOverride.trim().isNotEmpty)
          ? customClassOverride.trim()
          : [student.className, student.sectionName]
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

  static String generateCsv(PreparedAttendanceData preparedData) {
    final students = preparedData.parsedRows
        .map((row) => EvalBeeStudentData(
              rollNo: row.rollNo,
              name: row.studentName,
              className: row.className,
              sectionName: row.sectionName,
            ))
        .toList();
    return generateCsvFromStudents(students);
  }

  static Future<String?> fetchAndExportEvalBeeCsv({
    required GraphQLClient client,
    required String organisationId,
    required String? schoolId,
    required String? classId,
    required String? sectionId,
    required String fileName,
    String? customClassOverride,
  }) async {
    final result = await client.query(
      QueryOptions(
        document: gql(GqlQueries.getEvalBeeStudents),
        variables: {
          'organisationId': organisationId,
          'schoolId': schoolId,
          'classId': classId,
          'sectionId': sectionId,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception.toString()}');
    }

    final List<dynamic> rawStudents = result.data?['getEvalBeeStudents'] ?? [];
    if (rawStudents.isEmpty) {
      throw Exception('No matching student records found to export.');
    }

    final students = rawStudents.map((s) {
      final int? rollNo = s['roll_no'] != null ? int.tryParse(s['roll_no'].toString()) : null;
      final String name = s['name']?.toString() ?? '';
      final String className = s['class']?['name']?.toString() ?? '';
      final String sectionName = s['section']?['name']?.toString() ?? '';
      return EvalBeeStudentData(
        rollNo: rollNo,
        name: name,
        className: className,
        sectionName: sectionName,
      );
    }).toList();

    final csvContent = generateCsvFromStudents(students, customClassOverride: customClassOverride);
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    return await FilePicker.saveFile(
      dialogTitle: 'Save EvalBee CSV Report',
      fileName: fileName,
      bytes: bytes,
    );
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

