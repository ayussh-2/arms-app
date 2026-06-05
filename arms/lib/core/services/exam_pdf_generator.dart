import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../graphql/queries.dart';
import '../auth/auth_service.dart';
import '../constants/app_constants.dart';
import '../utils/app_date_utils.dart';
import '../utils/exam_html_generator.dart';
import '../utils/image_url_helper.dart';
import '../services/exam_lookup_cache.dart';
import '../../widgets/arms_snackbar.dart';

class ExamPdfGenerator {
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

  static Future<void> handleGeneratePdf({
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
              subjectMarksMap[subId] = 0.0;
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
            imageUrl: ImageUrlHelper.sanitizeUrl(student['image_url']?.toString()) ??
                AppConstants.getStudentImageUrl(student['roll_no']?.toString() ?? ''),
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

      final List<StudentMarkRow> rows = [];
      final totalMaxMarks = subjects.fold<double>(
        0.0,
        (sum, sub) => sum + sub.maxMarks,
      );

      for (int i = 0; i < tempStudents.length; i++) {
        final temp = tempStudents[i];
        final pct = totalMaxMarks > 0 ? (temp.total / totalMaxMarks) * 100 : 0.0;

        rows.add(
          StudentMarkRow(
            rollNo: temp.rollNo,
            name: temp.name,
            className: className,
            section: sectionName,
            imageUrl: temp.imageUrl,
            marks: temp.marks,
            total: temp.total,
            percentage: pct,
            rank: i + 1,
            isFail: pct < 40.0,
          ),
        );
      }

      final logoUrl = AuthService.currentAdmin?.organization?.logoURL ?? AppConstants.orgLogoUrl;
      final headerUrl = AuthService.currentAdmin?.organization?.headerURL ?? AppConstants.orgHeaderUrl;
      final title = examData?['name']?.toString() ?? exam['name']?.toString() ?? 'Exam Report';
      final dateStr = AppDateUtils.formatToDMY(
        DateTime.tryParse(examData?['exam_date']?.toString() ?? exam['exam_date']?.toString() ?? '') ?? DateTime.now(),
      );

      final htmlContent = ExamHtmlGenerator.generateHtml(
        rows: rows,
        subjects: subjects,
        preferences: prefs,
        orgLogoUrl: logoUrl,
        orgHeaderUrl: headerUrl,
        reportTitle: title,
        examDateString: dateStr,
      );

      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final pdfFormat = prefs.orientation == 'landscape' ? format.landscape : format.portrait;
          return await Printing.convertHtml(
            format: pdfFormat,
            html: htmlContent,
          );
        },
        name: title,
      );
    } catch (e) {
      if (context.mounted) {
        ArmsSnackbar.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }
}

class _TempStudentInfo {
  final String id;
  final String name;
  final String rollNo;
  final String? imageUrl;
  final Map<String, double> marks;
  final double total;
  final bool isAbsent;

  _TempStudentInfo({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.imageUrl,
    required this.marks,
    required this.total,
    required this.isAbsent,
  });
}
