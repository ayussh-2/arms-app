import 'dart:convert';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_dropdown_selector.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/attendance_html_generator.dart';
import '../../core/utils/image_url_helper.dart';
import '../../core/auth/auth_service.dart';

/// Interactive Export Sheet screen with real data fetching using GraphQL.
/// Supports date range picking (stacked vertically), dynamic schools/classes/sections lookups fetching,
/// and direct PDF exporting with loading state on the button (without inline preview).
class ExportSheetWidget extends StatefulWidget {
  const ExportSheetWidget({super.key});

  @override
  State<ExportSheetWidget> createState() => _ExportSheetWidgetState();
}

class _ExportSheetWidgetState extends State<ExportSheetWidget> {
  // --- Form State ---
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

  // --- Toggles State ---
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

  // --- Lookups State ---
  List<dynamic> _schools = [];
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];
  bool _isLoadingLookups = true;
  String? _lookupError;
  bool _hasFetched = false;

  // --- Export State ---
  bool _isExporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFetched) {
      _hasFetched = true;
      _fetchLookups();
    }
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
      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getLookups),
        variables: {'organisationId': orgId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (!mounted) return;

      if (result.hasException) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'Failed to load lookups: ${result.exception.toString()}';
        });
        return;
      }

      final lookups = result.data?['getLookups'];
      if (lookups == null) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'No lookup data returned from server.';
        });
        return;
      }

      setState(() {
        _schools = List.from(lookups['schools'] ?? []);
        _classes = List.from(lookups['classes'] ?? []);
        _sections = List.from(lookups['sections'] ?? []);
        _isLoadingLookups = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLookups = false;
          _lookupError = 'Connection error: $e';
        });
      }
    }
  }

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _fromDate : _toDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
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

  void _showSchoolPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select School', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('All schools', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: _selectedSchoolId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedSchoolId = null;
                        _selectedSchoolName = 'All schools';
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  ..._schools.map((s) => ListTile(
                    title: Text(s['name'] ?? '', style: AppTextStyles.bodyMedium),
                    trailing: _selectedSchoolId == s['id']?.toString() ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedSchoolId = s['id']?.toString();
                        _selectedSchoolName = s['name']?.toString();
                      });
                      Navigator.pop(ctx);
                    },
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClassPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Class', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('All classes', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: _selectedClassId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedClassId = null;
                        _selectedClassName = 'All classes';
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  ..._classes.map((c) => ListTile(
                    title: Text(c['name'] ?? '', style: AppTextStyles.bodyMedium),
                    trailing: _selectedClassId == c['id']?.toString() ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedClassId = c['id']?.toString();
                        _selectedClassName = c['name']?.toString();
                      });
                      Navigator.pop(ctx);
                    },
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Section', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('All sections', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: _selectedSectionId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedSectionId = null;
                        _selectedSectionName = 'All sections';
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  ..._sections.map((s) => ListTile(
                    title: Text(s['name'] ?? '', style: AppTextStyles.bodyMedium),
                    trailing: _selectedSectionId == s['id']?.toString() ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedSectionId = s['id']?.toString();
                        _selectedSectionName = s['name']?.toString();
                      });
                      Navigator.pop(ctx);
                    },
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportTypePicker() {
    final opts = ['Absent + Present', 'Only Absentees', 'Only Present'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Report Type', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            ...opts.map((o) => ListTile(
              title: Text(o, style: AppTextStyles.bodyMedium),
              trailing: _reportType == o ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _reportType = o);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSessionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Session', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            ...AttendanceSession.values.map((s) {
              final label = s == AttendanceSession.morningIn ? 'Morning In'
                  : s == AttendanceSession.morningOut ? 'Morning Out'
                  : s == AttendanceSession.eveningIn ? 'Evening In'
                  : 'Evening Out';
              return ListTile(
                title: Text(label, style: AppTextStyles.bodyMedium),
                trailing: _session == s ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _session = s);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Mode', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            ...AttendanceSheetMode.values.map((m) {
              final label = m == AttendanceSheetMode.sessionWise ? 'Session Wise' : 'Combine By Day';
              return ListTile(
                title: Text(label, style: AppTextStyles.bodyMedium),
                trailing: _mode == m ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _mode = m);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String? _parseRemark(String? rawRemarks) {
    if (rawRemarks == null || rawRemarks.isEmpty) return null;
    try {
      final parsed = jsonDecode(rawRemarks);
      if (parsed is Map) {
        return parsed['remark']?.toString() ?? parsed['text']?.toString() ?? parsed['notes']?.toString();
      }
    } catch (_) {}
    if (rawRemarks.startsWith('{')) return null;
    return rawRemarks;
  }

  Future<void> _exportPdfReport() async {
    final admin = AuthService.currentAdmin;
    final orgId = admin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No organization associated with this account.'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getAttendanceReportData),
        variables: {
          'organisationId': orgId,
          'fromDate': DateFormat('yyyy-MM-dd').format(_fromDate),
          'toDate': DateFormat('yyyy-MM-dd').format(_toDate),
          'schoolId': _selectedSchoolId,
          'classId': _selectedClassId,
          'sectionId': _selectedSectionId,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (!mounted) return;

      if (result.hasException) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.exception.toString()}'),
            backgroundColor: AppColors.errorText,
          ),
        );
        return;
      }

      final reportData = result.data?['getAttendanceReportData'];
      if (reportData == null) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No report data returned from server.'),
            backgroundColor: AppColors.errorText,
          ),
        );
        return;
      }

      final List<dynamic> rawStudents = reportData['students'] ?? [];
      final List<dynamic> rawAttendance = reportData['attendance'] ?? [];
      final List<dynamic> rawHolidays = reportData['holidays'] ?? [];
      final List<dynamic> rawLeaves = reportData['leaves'] ?? [];

      // 1. Generate date columns
      final List<String> dateColumns = [];
      DateTime tempDate = DateUtils.dateOnly(_fromDate);
      final normalizedToDate = DateUtils.dateOnly(_toDate);
      while (!tempDate.isAfter(normalizedToDate)) {
        final formatted = DateFormat('yyyy-MM-dd').format(tempDate);
        final isSunday = tempDate.weekday == DateTime.sunday;
        if (_showSundays || !isSunday) {
          dateColumns.add(formatted);
        }
        tempDate = tempDate.add(const Duration(days: 1));
      }

      // Order date columns
      if (_datesDescending) {
        dateColumns.sort((a, b) => b.compareTo(a));
      } else {
        dateColumns.sort((a, b) => a.compareTo(b));
      }

      // Hide unmarked days if toggle is set
      if (_hideUnmarkedDays) {
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
            monthYearGroups.add(MonthYearGroup(label: currentGroupLabel, dates: currentGroupDates));
            currentGroupLabel = label;
            currentGroupDates = [dateStr];
          }
        }
        if (currentGroupLabel != null) {
          monthYearGroups.add(MonthYearGroup(label: currentGroupLabel, dates: currentGroupDates));
        }
      }

      // 3. Process students into AttendanceSheetRow
      final List<AttendanceSheetRow> parsedRows = [];
      for (final student in rawStudents) {
        final studentId = student['id']?.toString() ?? '';
        final int? rollNo = student['roll_no'] != null ? int.tryParse(student['roll_no'].toString()) : null;
        final studentName = student['name']?.toString() ?? '';
        final schoolName = student['school']?['name']?.toString() ?? '';
        final className = student['class']?['name']?.toString() ?? '';
        final sectionName = student['section']?['name']?.toString() ?? '';

        final studentImageUrl = _includeStudentPic
            ? (ImageUrlHelper.sanitizeUrl(student['image_url']?.toString()) ?? AppConstants.getStudentImageUrl(rollNo))
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
              final schoolMatch = appSchools == null || appSchools.isEmpty || appSchools.contains(student['school_id']);
              final classMatch = appClasses == null || appClasses.isEmpty || appClasses.contains(student['class_id']);
              if (schoolMatch && classMatch) {
                holidayByDate[date] = hol['holiday_name'] ?? 'Holiday';
                break;
              }
            }
          }
        }

        // Attendance & Leaves mapping
        final Map<String, AttendanceStatus?> statusesByDate = {};
        final Map<String, Map<AttendanceSession, AttendanceStatus?>> sessionStatusesByDate = {};
        final Map<String, String?> remarksByDate = {};

        final studentAtt = rawAttendance.where((att) => att['student_id'] == studentId).toList();
        final studentLeaves = rawLeaves.where((l) => l['student_id'] == studentId && l['approved'] == true).toList();

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
              case 'present': return AttendanceStatus.present;
              case 'absent': return AttendanceStatus.absent;
              case 'leave': return AttendanceStatus.leave;
              case 'na': return AttendanceStatus.na;
              default: return null;
            }
          }

          AttendanceStatus? getSessionStatus(AttendanceSession sess) {
            if (entry == null) {
              return hasLeave ? AttendanceStatus.leave : null;
            }
            String? val;
            switch (sess) {
              case AttendanceSession.morningIn: val = entry['morning_in_status']; break;
              case AttendanceSession.morningOut: val = entry['morning_out_status']; break;
              case AttendanceSession.eveningIn: val = entry['evening_in_status']; break;
              case AttendanceSession.eveningOut: val = entry['evening_out_status']; break;
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
          statusesByDate[date] = getSessionStatus(_session);

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
        final percent = totalCount > 0 ? (presentCount / totalCount * 100).toStringAsFixed(0) : '0';
        final summary = '$presentCount / $totalCount ($percent%)';

        // Filter based on Report Type
        bool keepStudent = true;
        if (_reportType == 'Only Absentees') {
          keepStudent = statusesByDate.values.any((status) => status == AttendanceStatus.absent);
        } else if (_reportType == 'Only Present') {
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
        if (_removeBlankRows) {
          final hasAnyMarked = statusesByDate.values.any((s) => s != null);
          if (!hasAnyMarked) {
            keepStudent = false;
          }
        }

        if (keepStudent) {
          parsedRows.add(AttendanceSheetRow(
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
            holidayByDate: _showHolidays ? holidayByDate : const {},
          ));
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

      final preferences = AttendanceTemplatePreferences(
        theme: _isLightTheme ? ThemeMode.light : ThemeMode.dark,
        includeStudentPic: _includeStudentPic,
        showRollNo: _showRollNo,
        showSchool: _showSchool,
        showClassSection: _showClassSection,
        coloredStatus: _coloredStatus,
        isShortStatus: _isShortStatus,
        showRemarks: _showRemarks,
        showHeader: true,
        showLogo: true,
        customHeaderText: "Attendance Report",
      );

      final generatedHtml = AttendanceHtmlGenerator.generateHtml(
        visibleRows: parsedRows,
        dateColumns: dateColumns,
        monthYearGroups: monthYearGroups,
        preferences: preferences,
        sheetMode: _mode,
        attendanceSessions: [_session],
        orgLogoUrl: AppConstants.orgLogoUrl,
        orgHeaderUrl: AppConstants.orgHeaderUrl,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await Printing.convertHtml(format: format, html: generatedHtml);
        },
        name: 'Attendance_Report',
      );

      setState(() {
        _isExporting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLookups) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_lookupError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorText, size: 48),
              const SizedBox(height: 16),
              Text(_lookupError!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchLookups,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Retry Loading Lookups'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Configuration Card
        _sectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DATE RANGE',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'From Date',
                value: _formatDate(_fromDate),
                icon: Icons.calendar_today_outlined,
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'To Date',
                value: _formatDate(_toDate),
                icon: Icons.calendar_today_outlined,
                onTap: () => _pickDate(false),
              ),
              const SizedBox(height: 24),
              Text(
                'FILTERS',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'Report Type',
                value: _reportType,
                icon: Icons.assignment_outlined,
                onTap: _showReportTypePicker,
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'Session',
                value: _session == AttendanceSession.morningIn ? 'Morning In'
                    : _session == AttendanceSession.morningOut ? 'Morning Out'
                    : _session == AttendanceSession.eveningIn ? 'Evening In'
                    : 'Evening Out',
                icon: Icons.access_time_outlined,
                onTap: _showSessionPicker,
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'Mode',
                value: _mode == AttendanceSheetMode.sessionWise ? 'Session Wise' : 'Combine By Day',
                icon: Icons.grid_view_outlined,
                onTap: _showModePicker,
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'School',
                value: _selectedSchoolName,
                icon: Icons.school_outlined,
                onTap: _showSchoolPicker,
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'Class',
                value: _selectedClassName,
                icon: Icons.class_outlined,
                onTap: _showClassPicker,
              ),
              const SizedBox(height: 16),
              ArmsDropdownSelector(
                label: 'Section',
                value: _selectedSectionName,
                icon: Icons.splitscreen_outlined,
                onTap: _showSectionPicker,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutterCard),

        // Display Toggles Card
        _sectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLUMNS & DISPLAY CONFIG',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              _toggleRow('Include Student Photo', _includeStudentPic, (v) => setState(() => _includeStudentPic = v)),
              _toggleRow('Show Roll No', _showRollNo, (v) => setState(() => _showRollNo = v)),
              _toggleRow('Show School', _showSchool, (v) => setState(() => _showSchool = v)),
              _toggleRow('Show Class/Section', _showClassSection, (v) => setState(() => _showClassSection = v)),
              _toggleRow('Short Status (P / A)', _isShortStatus, (v) => setState(() => _isShortStatus = v)),
              _toggleRow('Colored Status labels', _coloredStatus, (v) => setState(() => _coloredStatus = v)),
              _toggleRow('Light Theme', _isLightTheme, (v) => setState(() => _isLightTheme = v)),
              _toggleRow('Show Holidays', _showHolidays, (v) => setState(() => _showHolidays = v)),
              _toggleRow('Show Sundays', _showSundays, (v) => setState(() => _showSundays = v)),
              _toggleRow('Remove Blank Rows', _removeBlankRows, (v) => setState(() => _removeBlankRows = v)),
              _toggleRow('Show Remarks', _showRemarks, (v) => setState(() => _showRemarks = v)),
              _toggleRow('Hide Unmarked Days', _hideUnmarkedDays, (v) => setState(() => _hideUnmarkedDays = v)),
              _toggleRow('Dates Descending', _datesDescending, (v) => setState(() => _datesDescending = v)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutterCard),

        // Action Button
        Padding(
          padding: const EdgeInsets.only(bottom: 48),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _exportPdfReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              child: _isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Export PDF',
                          style: AppTextStyles.headerSmall.copyWith(
                            color: AppColors.onPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.marginPage),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _toggleRow(String title, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Switch.adaptive(
            value: val,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
