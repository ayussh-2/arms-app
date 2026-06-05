import 'dart:convert';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../graphql/queries.dart';
import '../utils/image_url_helper.dart';
import '../utils/attendance_html_generator.dart';
import '../constants/app_constants.dart';

class PreparedAttendanceData {
  final List<AttendanceSheetRow> parsedRows;
  final List<String> dateColumns;
  final List<MonthYearGroup> monthYearGroups;

  PreparedAttendanceData({
    required this.parsedRows,
    required this.dateColumns,
    required this.monthYearGroups,
  });
}

class AttendanceReportService {
  static String? _parseRemark(String? rawRemarks) {
    if (rawRemarks == null || rawRemarks.isEmpty) return null;
    try {
      final parsed = jsonDecode(rawRemarks);
      if (parsed is Map) {
        return parsed['remark']?.toString() ??
            parsed['text']?.toString() ??
            parsed['notes']?.toString();
      }
    } catch (_) {}
    if (rawRemarks.startsWith('{')) return null;
    return rawRemarks;
  }

  static Future<PreparedAttendanceData> fetchAndPrepareData({
    required GraphQLClient client,
    required String organisationId,
    required DateTime fromDate,
    required DateTime toDate,
    required String? schoolId,
    required String? classId,
    required String? sectionId,
    required bool showSundays,
    required bool datesDescending,
    required bool hideUnmarkedDays,
    required bool includeStudentPic,
    required String reportType,
    required bool removeBlankRows,
    required bool showHolidays,
    required AttendanceSession session,
  }) async {
    final result = await client.query(
      QueryOptions(
        document: gql(GqlQueries.getAttendanceReportData),
        variables: {
          'organisationId': organisationId,
          'fromDate': DateFormat('yyyy-MM-dd').format(fromDate),
          'toDate': DateFormat('yyyy-MM-dd').format(toDate),
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

    final reportData = result.data?['getAttendanceReportData'];
    if (reportData == null) {
      throw Exception('No report data returned from server.');
    }

    final List<dynamic> rawStudents = reportData['students'] ?? [];
    final List<dynamic> rawAttendance = reportData['attendance'] ?? [];
    final List<dynamic> rawHolidays = reportData['holidays'] ?? [];
    final List<dynamic> rawLeaves = reportData['leaves'] ?? [];

    // 1. Generate date columns
    final List<String> dateColumns = [];
    DateTime tempDate = DateUtils.dateOnly(fromDate);
    final normalizedToDate = DateUtils.dateOnly(toDate);
    while (!tempDate.isAfter(normalizedToDate)) {
      final formatted = DateFormat('yyyy-MM-dd').format(tempDate);
      final isSunday = tempDate.weekday == DateTime.sunday;
      if (showSundays || !isSunday) {
        dateColumns.add(formatted);
      }
      tempDate = tempDate.add(const Duration(days: 1));
    }

    // Order date columns
    if (datesDescending) {
      dateColumns.sort((a, b) => b.compareTo(a));
    } else {
      dateColumns.sort((a, b) => a.compareTo(b));
    }

    // Hide unmarked days if toggle is set
    if (hideUnmarkedDays) {
      final markedDates = <String>{};
      final studentIds = rawStudents.map((s) => s['id']?.toString()).toSet();
      for (final att in rawAttendance) {
        final studentId = att['student_id']?.toString();
        if (studentId != null && studentIds.contains(studentId)) {
          final date = att['attendance_date'];
          if (date != null) markedDates.add(date);
        }
      }
      for (final hol in rawHolidays) {
        final fromStr = hol['from_date']?.toString();
        final toStr = hol['to_date']?.toString();
        if (fromStr == null || toStr == null) continue;
        final f = DateTime.tryParse(fromStr);
        final t = DateTime.tryParse(toStr);
        if (f == null || t == null) continue;
        DateTime d = f;
        while (!d.isAfter(t)) {
          markedDates.add(DateFormat('yyyy-MM-dd').format(d));
          d = d.add(const Duration(days: 1));
        }
      }
      dateColumns.retainWhere((date) => markedDates.contains(date));
    }

    // 2. Compute MonthYearGroups
    final List<MonthYearGroup> monthYearGroups = [];
    if (dateColumns.isNotEmpty) {
      String? currentGroupLabel;
      List<String> currentGroupDates = [];
      for (final dateStr in dateColumns) {
        final date = DateTime.parse(dateStr);
        final label = DateFormat('MMM yyyy').format(date);
        if (currentGroupLabel == null) {
          currentGroupLabel = label;
          currentGroupDates = [dateStr];
        } else if (currentGroupLabel == label) {
          currentGroupDates.add(dateStr);
        } else {
          monthYearGroups.add(
            MonthYearGroup(
              label: currentGroupLabel,
              dates: currentGroupDates,
            ),
          );
          currentGroupLabel = label;
          currentGroupDates = [dateStr];
        }
      }
      if (currentGroupLabel != null) {
        monthYearGroups.add(
          MonthYearGroup(label: currentGroupLabel, dates: currentGroupDates),
        );
      }
    }

    // 3. Process students into AttendanceSheetRow
    final List<AttendanceSheetRow> parsedRows = [];
    for (final student in rawStudents) {
      final studentId = student['id']?.toString() ?? '';
      final int? rollNo =
          student['roll_no'] != null
              ? int.tryParse(student['roll_no'].toString())
              : null;
      final studentName = student['name']?.toString() ?? '';
      final schoolName = student['school']?['name']?.toString() ?? '';
      final className = student['class']?['name']?.toString() ?? '';
      final sectionName = student['section']?['name']?.toString() ?? '';

      final studentImageUrl =
          includeStudentPic
              ? (ImageUrlHelper.sanitizeUrl(
                    student['image_url']?.toString(),
                  ) ??
                  AppConstants.getStudentImageUrl(rollNo))
              : null;

      // Holidays
      final Map<String, String?> holidayByDate = {};
      for (final date in dateColumns) {
        final dt = DateTime.parse(date);
        for (final hol in rawHolidays) {
          final fromStr = hol['from_date']?.toString();
          final toStr = hol['to_date']?.toString();
          if (fromStr == null || toStr == null) continue;
          final from = DateTime.tryParse(fromStr);
          final to = DateTime.tryParse(toStr);
          if (from == null || to == null) continue;
          if (!dt.isBefore(from) && !dt.isAfter(to)) {
            final appSchools = hol['applies_to_school_ids'] as List?;
            final appClasses = hol['applies_to_class_ids'] as List?;
            final schoolMatch =
                appSchools == null ||
                appSchools.isEmpty ||
                appSchools.contains(student['school_id']);
            final classMatch =
                appClasses == null ||
                appClasses.isEmpty ||
                appClasses.contains(student['class_id']);
            if (schoolMatch && classMatch) {
              holidayByDate[date] = hol['holiday_name'] ?? 'Holiday';
              break;
            }
          }
        }
      }

      // Attendance & Leaves mapping
      final Map<String, AttendanceStatus?> statusesByDate = {};
      final Map<String, Map<AttendanceSession, AttendanceStatus?>>
      sessionStatusesByDate = {};
      final Map<String, String?> remarksByDate = {};

      final studentAtt =
          rawAttendance
              .where((att) => att['student_id'] == studentId)
              .toList();
      final studentLeaves =
          rawLeaves
              .where(
                (l) => l['student_id'] == studentId && l['approved'] == true,
              )
              .toList();

      for (final date in dateColumns) {
        final dt = DateTime.parse(date);
        final entry = studentAtt.firstWhere(
          (att) => att['attendance_date'] == date,
          orElse: () => null,
        );

        final hasLeave = studentLeaves.any((l) {
          final fromStr = l['from_date']?.toString();
          final toStr = l['to_date']?.toString();
          if (fromStr == null || toStr == null) return false;
          final from = DateTime.tryParse(fromStr);
          final to = DateTime.tryParse(toStr);
          if (from == null || to == null) return false;
          return !dt.isBefore(from) && !dt.isAfter(to);
        });

        AttendanceStatus? parseStatus(String? statusStr) {
          if (statusStr == null) return null;
          switch (statusStr.toLowerCase()) {
            case 'present':
              return AttendanceStatus.present;
            case 'absent':
              return AttendanceStatus.absent;
            case 'leave':
              return AttendanceStatus.leave;
            case 'na':
              return AttendanceStatus.na;
            default:
              return null;
          }
        }

        AttendanceStatus? getSessionStatus(AttendanceSession sess) {
          if (entry == null) {
            return hasLeave ? AttendanceStatus.leave : null;
          }
          String? val;
          switch (sess) {
            case AttendanceSession.morningIn:
              val = entry['morning_in_status'];
              break;
            case AttendanceSession.morningOut:
              val = entry['morning_out_status'];
              break;
            case AttendanceSession.eveningIn:
              val = entry['evening_in_status'];
              break;
            case AttendanceSession.eveningOut:
              val = entry['evening_out_status'];
              break;
          }
          final parsed = parseStatus(val);
          if (parsed == null && hasLeave) {
            return AttendanceStatus.leave;
          }
          return parsed;
        }

        final sessionsMap = <AttendanceSession, AttendanceStatus?>{};
        for (final sess in AttendanceSession.values) {
          sessionsMap[sess] = getSessionStatus(sess);
        }
        sessionStatusesByDate[date] = sessionsMap;

        // dailyStatus
        statusesByDate[date] = getSessionStatus(session);

        // remarks
        if (entry != null && entry['remarks'] != null) {
          remarksByDate[date] = _parseRemark(entry['remarks']);
        }
      }

      // Summary
      int presentCount = 0;
      int totalCount = 0;
      for (final date in dateColumns) {
        if (holidayByDate[date] != null) continue;
        totalCount++;
        if (statusesByDate[date] == AttendanceStatus.present) {
          presentCount++;
        }
      }
      final percent =
          totalCount > 0
              ? (presentCount / totalCount * 100).toStringAsFixed(0)
              : '0';
      final summary = '$presentCount / $totalCount ($percent%)';

      // Filter based on Report Type
      bool keepStudent = true;
      if (reportType == 'Only Absentees') {
        keepStudent = statusesByDate.values.any(
          (status) => status == AttendanceStatus.absent,
        );
      } else if (reportType == 'Only Present') {
        bool hasMarked = false;
        bool hasAbsent = false;
        for (final date in dateColumns) {
          if (holidayByDate[date] != null) continue;
          final s = statusesByDate[date];
          if (s != null) {
            hasMarked = true;
            if (s == AttendanceStatus.absent) hasAbsent = true;
          }
        }
        keepStudent = hasMarked && !hasAbsent;
      }

      // Filter blank rows
      if (removeBlankRows) {
        final hasAnyMarked = statusesByDate.values.any((s) => s != null);
        if (!hasAnyMarked) {
          keepStudent = false;
        }
      }

      if (keepStudent) {
        parsedRows.add(
          AttendanceSheetRow(
            studentId: studentId,
            rollNo: rollNo,
            studentName: studentName,
            schoolName: schoolName,
            className: className,
            sectionName: sectionName,
            summary: summary,
            studentImageUrl: studentImageUrl,
            statusesByDate: statusesByDate,
            sessionStatusesByDate: sessionStatusesByDate,
            remarksByDate: remarksByDate,
            holidayByDate: showHolidays ? holidayByDate : const {},
          ),
        );
      }
    }

    // Sort rows
    parsedRows.sort((a, b) {
      if (a.rollNo != null && b.rollNo != null) {
        return a.rollNo!.compareTo(b.rollNo!);
      }
      if (a.rollNo != null) return -1;
      if (b.rollNo != null) return 1;
      return a.studentName.compareTo(b.studentName);
    });

    return PreparedAttendanceData(
      parsedRows: parsedRows,
      dateColumns: dateColumns,
      monthYearGroups: monthYearGroups,
    );
  }
}
