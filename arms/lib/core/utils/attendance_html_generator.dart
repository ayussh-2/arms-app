// --- Data Models ---
enum AttendanceSession { morningIn, morningOut, eveningIn, eveningOut }

enum AttendanceSheetMode { sessionWise, combineByDay }

enum AttendanceStatus { present, absent, leave, na }

enum ThemeMode { light, dark }

class AttendanceTemplatePreferences {
  final ThemeMode theme;
  final bool includeStudentPic;
  final bool showRollNo;
  final bool showSchool;
  final bool showClassSection;
  final bool showRemarks;
  final bool coloredStatus;
  final bool isShortStatus;
  final bool alternateShading;
  final bool showLogo;
  final bool showHeader;
  final String customHeaderText;
  final int fontSize;
  final int margin;
  final String orientation;
  final String pageSize;

  AttendanceTemplatePreferences({
    this.theme = ThemeMode.light,
    this.includeStudentPic = false,
    this.showRollNo = true,
    this.showSchool = true,
    this.showClassSection = true,
    this.showRemarks = false,
    this.coloredStatus = true,
    this.isShortStatus = true,
    this.alternateShading = true,
    this.showLogo = true,
    this.showHeader = true,
    this.customHeaderText = '',
    this.fontSize = 13,
    this.margin = 10,
    this.orientation = 'portrait',
    this.pageSize = 'A4',
  });
}

class MonthYearGroup {
  final String label;
  final List<String> dates;
  MonthYearGroup({required this.label, required this.dates});
}

class AttendanceSheetRow {
  final String studentId;
  final int? rollNo;
  final String studentName;
  final String schoolName;
  final String className;
  final String sectionName;
  final String summary;
  final String? studentImageUrl;

  final Map<String, AttendanceStatus?> statusesByDate;
  final Map<String, Map<AttendanceSession, AttendanceStatus?>>
  sessionStatusesByDate;
  final Map<String, String?> remarksByDate;
  final Map<String, String?> holidayByDate;

  AttendanceSheetRow({
    required this.studentId,
    this.rollNo,
    required this.studentName,
    required this.schoolName,
    required this.className,
    required this.sectionName,
    required this.summary,
    this.studentImageUrl,
    this.statusesByDate = const {},
    this.sessionStatusesByDate = const {},
    this.remarksByDate = const {},
    this.holidayByDate = const {},
  });
}

/// --- HTML Generator Service ---
class AttendanceHtmlGenerator {
  static String generateHtml({
    required List<AttendanceSheetRow> visibleRows,
    required List<String> dateColumns,
    required List<MonthYearGroup> monthYearGroups,
    required AttendanceTemplatePreferences preferences,
    required AttendanceSheetMode sheetMode,
    required List<AttendanceSession> attendanceSessions,
    String? orgLogoUrl,
    String? orgHeaderUrl,
    String? principalSignUrl,
    String? teacherSignUrl,
  }) {
    final buffer = StringBuffer();

    final isLight = preferences.theme == ThemeMode.light;
    final themePrefix = isLight ? "light" : "dark";

    // PURE PLAIN-TABLE CSS
    final String embeddedCss = '''
      :root {
        --border-color: ${isLight ? '#d1d5db' : '#4b5563'};
      }
      * { box-sizing: border-box; -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
      html, body { margin: 0; padding: 0; font-family: Arial, sans-serif; background: #ffffff; }

      /* Added padding back to the main container */
      .report { font-size: ${preferences.fontSize}px; padding: 24px; max-width: 100%; margin: 0 auto; }
      .shell-light { background: #ffffff; color: #111827; }
      .shell-dark { background: #1f2937; color: #f9fafb; }

      /* width: 100% forces the table to stretch and match the header width */
      table { border-collapse: collapse; width: 100%; font-size: inherit; margin-top: 16px; }
      th, td { border: 1px solid var(--border-color); padding: 10px 12px; }
      th { text-align: left; font-weight: 600; }
      .text-center { text-align: center; }
      .whitespace-nowrap { white-space: nowrap; }

      .th-light { background: #f3f4f6; color: #111827; }
      .th-dark { background: #374151; color: #ffffff; }

      .tr-base-light { background: #ffffff; }
      .tr-base-dark { background: #1f2937; }
      .tr-alt-light { background: #fef3c7; }
      .tr-alt-dark { background: #1e293b; }

      .holiday-light { background: #fde68a; color: #92400e; font-weight: bold; }
      .holiday-dark { background: #92400e; color: #fde68a; font-weight: bold; }

      .status-present-light { background: #d1fae5; color: #065f46; }
      .status-present-dark { background: rgba(16, 185, 129, 0.2); color: #d1fae5; }

      .status-absent-light { background: #ffe4e6; color: #9f1239; }
      .status-absent-dark { background: rgba(244, 63, 94, 0.2); color: #ffe4e6; }

      .status-na-light { background: #fef3c7; color: #92400e; }
      .status-na-dark { background: rgba(245, 158, 11, 0.2); color: #fef3c7; }

      .status-uncolored { background: transparent; }

      .flex-row { display: flex; align-items: center; gap: 8px; }
      .header-block { border-bottom: 1px solid var(--border-color); padding-bottom: 12px; }

      /* Centered Flexbox for the Logo and Header */

      /* Header & Logo styling */
      .org-container {
        display: grid;
        grid-template-columns: 1fr auto 1fr; /* 3 columns: Left, Center, Right */
        align-items: center;
        padding: 12px 16px;
        border: 1px solid var(--border-color);
        background: ${isLight ? '#f9fafb' : '#111827'};
        border-radius: 6px;
      }
      .org-logo { height: 50px; width: 50px; object-fit: contain; }
      .org-header { height: 50px; max-width: 400px; object-fit: contain; }

      /* Student Thumbnail - changed to contain to prevent cropping heads */
      .student-thumb { height: 32px; width: 32px; flex-shrink: 0; border: 1px solid var(--border-color); object-fit: contain; background-color: white; border-radius: 4px; }


      @media print {
        body { background: #fff !important; }
        .shell-dark, .shell-light { color: #000 !important; background: #fff !important; }
        .th-dark, .th-light { color: #000 !important; }
        table { break-inside: auto !important; page-break-inside: auto !important; }
        tr, td, th { break-inside: avoid !important; page-break-inside: avoid !important; page-break-after: auto !important; }
      }
      @page { size: ${preferences.pageSize} ${preferences.orientation}; margin: ${preferences.margin}mm; }
    ''';

    buffer.writeln('''
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Attendance Sheet</title>
        <style>$embeddedCss</style>
      </head>
      <body>
        <div class="report shell-$themePrefix">
    ''');

    // --- HEADER SECTION ---
    // --- HEADER SECTION ---
    buffer.writeln('<div class="header-block">');
    if ((preferences.showHeader && orgHeaderUrl != null) ||
        (preferences.showLogo && orgLogoUrl != null)) {
      buffer.writeln('<div class="org-container">');

      // Left Column: Logo
      buffer.writeln(
        '<div style="display: flex; justify-content: flex-start; align-items: center;">',
      );
      if (preferences.showLogo && orgLogoUrl != null) {
        buffer.writeln(
          '<img src="$orgLogoUrl" class="org-logo" alt="Organisation logo"/>',
        );
      }
      buffer.writeln('</div>');

      // Center Column: Header Image
      buffer.writeln(
        '<div style="display: flex; justify-content: center; align-items: center;">',
      );
      if (preferences.showHeader && orgHeaderUrl != null) {
        buffer.writeln(
          '<img src="$orgHeaderUrl" class="org-header" alt="Organisation header"/>',
        );
      }
      buffer.writeln('</div>');

      // Right Column: Empty Spacer (Keeps the middle column perfectly centered)
      buffer.writeln('<div></div>');

      buffer.writeln('</div>');
    }

    if (preferences.customHeaderText.isNotEmpty) {
      buffer.writeln(
        '<div style="text-align: center; margin-top: 16px;"><h3 style="margin:0; font-size: 1.1em;">${_escapeHtml(preferences.customHeaderText)}</h3></div>',
      );
    }
    buffer.writeln('</div>');

    // --- TABLE SECTION ---
    buffer.writeln('<div style="overflow-x: auto;">');
    buffer.writeln('<table><thead>');

    final rowSpanCount = sheetMode == AttendanceSheetMode.sessionWise ? 3 : 2;

    buffer.writeln('<tr class="th-$themePrefix">');
    buffer.writeln('<th rowspan="$rowSpanCount">Sl. No.</th>');
    if (preferences.showRollNo) {
      buffer.writeln('<th rowspan="$rowSpanCount">Roll No.</th>');
    }
    buffer.writeln(
      '<th rowspan="$rowSpanCount" style="width: 20%;">Student</th>',
    ); // Give student column bit more space
    if (preferences.showSchool) {
      buffer.writeln('<th rowspan="$rowSpanCount">School</th>');
    }
    if (preferences.showClassSection) {
      buffer.writeln('<th rowspan="$rowSpanCount">Std</th>');
    }
    buffer.writeln(
      '<th class="whitespace-nowrap" rowspan="$rowSpanCount">Summary</th>',
    );

    for (var group in monthYearGroups) {
      final colSpan =
          sheetMode == AttendanceSheetMode.sessionWise
              ? group.dates.length * attendanceSessions.length
              : group.dates.length;
      buffer.writeln(
        '<th class="whitespace-nowrap text-center" colspan="$colSpan">${group.label}</th>',
      );
    }

    if (preferences.showRemarks) {
      buffer.writeln(
        '<th rowspan="$rowSpanCount" style="width: 25%;">Remarks</th>',
      );
    }
    buffer.writeln('</tr>');

    buffer.writeln('<tr class="th-$themePrefix">');
    for (var date in dateColumns) {
      final colSpan =
          sheetMode == AttendanceSheetMode.sessionWise
              ? attendanceSessions.length
              : 1;
      buffer.writeln(
        '<th class="text-center whitespace-nowrap" colspan="$colSpan">${_formatDateNumberLabel(date)}</th>',
      );
    }
    buffer.writeln('</tr>');

    if (sheetMode == AttendanceSheetMode.sessionWise) {
      buffer.writeln('<tr class="th-$themePrefix">');
      for (var _ in dateColumns) {
        for (var session in attendanceSessions) {
          buffer.writeln(
            '<th class="text-center whitespace-nowrap" style="font-size: 0.85em;">${_getSessionLabel(session)}</th>',
          );
        }
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</thead><tbody>');

    // --- TABLE BODY (DATA) ---
    for (var i = 0; i < visibleRows.length; i++) {
      final row = visibleRows[i];
      final isEven = i % 2 == 0;
      final rowClass =
          preferences.alternateShading
              ? (isEven ? "tr-base-$themePrefix" : "tr-alt-$themePrefix")
              : "tr-base-$themePrefix";

      buffer.writeln('<tr class="$rowClass">');

      buffer.writeln('<td>${i + 1}</td>');
      if (preferences.showRollNo) {
        buffer.writeln('<td>${row.rollNo ?? "-"}</td>');
      }

      buffer.writeln('<td style="font-weight: 500;">');
      buffer.writeln('<div class="flex-row">');
      if (preferences.includeStudentPic && row.studentImageUrl != null) {
        buffer.writeln(
          '<img alt="${_escapeHtml(row.studentName)} thumbnail" class="student-thumb" src="${row.studentImageUrl}">',
        );
      }
      buffer.writeln('<span>${_escapeHtml(row.studentName)}</span></div></td>');

      if (preferences.showSchool) {
        buffer.writeln('<td>${_escapeHtml(row.schoolName)}</td>');
      }
      if (preferences.showClassSection) {
        final secStr =
            row.sectionName.isNotEmpty ? ' - ${row.sectionName}' : '';
        buffer.writeln(
          '<td class="whitespace-nowrap">${_escapeHtml(row.className)}$secStr</td>',
        );
      }
      buffer.writeln('<td class="whitespace-nowrap">${row.summary}</td>');

      if (sheetMode == AttendanceSheetMode.combineByDay) {
        for (var date in dateColumns) {
          final holidayName = row.holidayByDate[date];
          if (holidayName != null) {
            final holidayChar = _getHolidayCellLabel(
              holidayName,
              i,
              visibleRows.length,
            );
            buffer.writeln(
              '<td class="text-center holiday-$themePrefix" title="$holidayName">$holidayChar</td>',
            );
          } else {
            final status = row.statusesByDate[date];
            final statusClass = _getStatusCellClassName(
              status,
              preferences,
              themePrefix,
            );
            final statusLabel = _getStatusDisplayLabel(
              status,
              preferences.isShortStatus ? 'short' : 'full',
            );
            buffer.writeln(
              '<td class="text-center $statusClass" style="font-size: 0.9em; font-weight: bold;">$statusLabel</td>',
            );
          }
        }
      } else {
        for (var date in dateColumns) {
          final holidayName = row.holidayByDate[date];
          if (holidayName != null) {
            final holidayChar = _getHolidayCellLabel(
              holidayName,
              i,
              visibleRows.length,
            );
            buffer.writeln(
              '<td colspan="${attendanceSessions.length}" class="text-center holiday-$themePrefix" title="$holidayName">$holidayChar</td>',
            );
          } else {
            for (var session in attendanceSessions) {
              final status = row.sessionStatusesByDate[date]?[session];
              final statusClass = _getStatusCellClassName(
                status,
                preferences,
                themePrefix,
              );
              final statusLabel = _getStatusDisplayLabel(
                status,
                preferences.isShortStatus ? 'short' : 'full',
              );
              buffer.writeln(
                '<td class="text-center $statusClass" style="font-size: 0.9em; font-weight: bold;">$statusLabel</td>',
              );
            }
          }
        }
      }

      if (preferences.showRemarks) {
        buffer.writeln('<td>');
        final remarkStrings = <String>[];
        for (var date in dateColumns) {
          if (row.remarksByDate[date] != null &&
              row.remarksByDate[date]!.isNotEmpty) {
            remarkStrings.add(
              "$date: ${_escapeHtml(row.remarksByDate[date]!)}",
            );
          }
        }
        buffer.writeln(remarkStrings.isEmpty ? "-" : remarkStrings.join(" | "));
        buffer.writeln('</td>');
      }
      buffer.writeln('</tr>');
    }

    buffer.writeln('</tbody></table></div>');

    // --- SIGNATURES ---
    if (principalSignUrl != null || teacherSignUrl != null) {
      buffer.writeln(
        '<div style="margin-top: 40px; display: flex; justify-content: space-between;">',
      );
      if (teacherSignUrl != null) {
        buffer.writeln('''
          <div style="text-align: center; font-size: 12px;">
            <img src="$teacherSignUrl" style="height: 60px; width: 150px; object-fit: contain; margin-bottom: 4px;"/>
            <div style="border-top: 1px solid var(--border-color); padding-top: 8px;">Class Teacher</div>
          </div>
         ''');
      } else {
        buffer.writeln('<span></span>');
      }
      if (principalSignUrl != null && teacherSignUrl == null) {
        buffer.writeln('''
          <div style="text-align: center; font-size: 12px;">
            <img src="$principalSignUrl" style="height: 60px; width: 150px; object-fit: contain; margin-bottom: 4px;"/>
            <div style="border-top: 1px solid var(--border-color); padding-top: 8px;">Principal</div>
          </div>
         ''');
      }
      buffer.writeln('</div>');
    }
    buffer.writeln('</div></body></html>');
    return buffer.toString();
  }

  static String _formatDateNumberLabel(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length == 3) return parts[2];
    } catch (_) {}
    return dateString;
  }

  static String _getSessionLabel(AttendanceSession session) {
    switch (session) {
      case AttendanceSession.morningIn:
        return "Morning In";
      case AttendanceSession.morningOut:
        return "Morning Out";
      case AttendanceSession.eveningIn:
        return "Evening In";
      case AttendanceSession.eveningOut:
        return "Evening Out";
    }
  }

  static String _getHolidayCellLabel(
    String holidayName,
    int rowIndex,
    int totalRows,
  ) {
    final text = holidayName.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (text.isEmpty) return "";
    if (text.length <= totalRows) {
      return rowIndex < text.length ? text[rowIndex] : "";
    }
    return rowIndex < totalRows - 1
        ? text[rowIndex]
        : text.substring(totalRows - 1);
  }

  static String _getStatusDisplayLabel(AttendanceStatus? status, String mode) {
    if (status == null) return mode == 'short' ? "-" : "UNMARKED";
    if (mode == 'short') {
      switch (status) {
        case AttendanceStatus.present:
          return "P";
        case AttendanceStatus.leave:
          return "L";
        case AttendanceStatus.na:
          return "N";
        case AttendanceStatus.absent:
          return "A";
      }
    }
    return status.name.toUpperCase();
  }

  static String _getStatusCellClassName(
    AttendanceStatus? status,
    AttendanceTemplatePreferences prefs,
    String themePrefix,
  ) {
    if (!prefs.coloredStatus) return "status-uncolored";
    switch (status) {
      case AttendanceStatus.present:
        return "status-present-$themePrefix";
      case AttendanceStatus.na:
        return "status-na-$themePrefix";
      case AttendanceStatus.absent:
      case AttendanceStatus.leave:
        return "status-absent-$themePrefix";
      case null:
        return "status-na-$themePrefix";
    }
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
