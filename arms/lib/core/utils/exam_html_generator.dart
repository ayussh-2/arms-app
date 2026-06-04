/// --- Data Models ---
class ExamReportPreferences {
  final bool isMultiExam;
  final bool includeStudentPic;
  final bool showMaxMarks;
  final bool showGrandTotal;
  final bool showOverallPercentage;
  final bool showOverallRank;
  final String pageSize;
  final String orientation;
  final int margin;
  final String theme; // 'light' or 'dark'

  ExamReportPreferences({
    this.isMultiExam = false,
    this.includeStudentPic = true,
    this.showMaxMarks = true,
    this.showGrandTotal = true,
    this.showOverallPercentage = true,
    this.showOverallRank = true,
    this.pageSize = 'A4',
    this.orientation = 'portrait',
    this.margin = 10,
    this.theme = 'light',
  });

  ExamReportPreferences copyWith({
    bool? isMultiExam,
    bool? includeStudentPic,
    bool? showMaxMarks,
    bool? showGrandTotal,
    bool? showOverallPercentage,
    bool? showOverallRank,
    String? pageSize,
    String? orientation,
    int? margin,
    String? theme,
  }) {
    return ExamReportPreferences(
      isMultiExam: isMultiExam ?? this.isMultiExam,
      includeStudentPic: includeStudentPic ?? this.includeStudentPic,
      showMaxMarks: showMaxMarks ?? this.showMaxMarks,
      showGrandTotal: showGrandTotal ?? this.showGrandTotal,
      showOverallPercentage:
          showOverallPercentage ?? this.showOverallPercentage,
      showOverallRank: showOverallRank ?? this.showOverallRank,
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      margin: margin ?? this.margin,
      theme: theme ?? this.theme,
    );
  }
}

class SubjectColumn {
  final String key;
  final String label;
  final int maxMarks;

  SubjectColumn({
    required this.key,
    required this.label,
    required this.maxMarks,
  });
}

class StudentMarkRow {
  final String rollNo;
  final String name;
  final String className;
  final String section;
  final String? imageUrl;
  final Map<String, double> marks;
  final double total;
  final double percentage;
  final int rank;
  final bool isFail;

  StudentMarkRow({
    required this.rollNo,
    required this.name,
    required this.className,
    required this.section,
    this.imageUrl,
    required this.marks,
    required this.total,
    required this.percentage,
    required this.rank,
    this.isFail = false,
  });
}

/// --- HTML Generator Service ---
class ExamHtmlGenerator {
  static String generateHtml({
    required List<StudentMarkRow> rows,
    required List<SubjectColumn> subjects,
    required ExamReportPreferences preferences,
    String? orgLogoUrl,
    String? orgHeaderUrl,
    String? reportTitle,
    String? examDateString,
  }) {
    final buffer = StringBuffer();
    final grandMax = subjects.fold<int>(0, (sum, item) => sum + item.maxMarks);

    String withMax(String label, int max) =>
        preferences.showMaxMarks ? "$label ($max)" : label;

    final isLight = preferences.theme == 'light';
    final themePrefix = isLight ? "light" : "dark";

    // CSS synchronized with attendance_html_generator.dart
    // final String embeddedCss = '''
    //   :root {
    //     --border-color: ${isLight ? '#d1d5db' : '#4b5563'};
    //   }
    //   * { box-sizing: border-box; -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
    //   html, body { margin: 0; padding: 0; font-family: Arial, sans-serif; background: #ffffff; }

    //   .report { font-size: 13px; padding: 24px; max-width: 100%; margin: 0 auto; }
    //   .shell-light { background: #ffffff; color: #111827; }
    //   .shell-dark { background: #1f2937; color: #f9fafb; }

    //   /* Table Width fix: Hugs content instead of stretching to 100% on small exams */
    //   table { border-collapse: collapse; width: max-content; min-width: 50%; font-size: inherit; margin-top: 16px; }
    //   th, td { border: 1px solid var(--border-color); padding: 8px 12px; }
    //   th { text-align: center; font-weight: 600; }
    //   td { text-align: center; vertical-align: middle; }
    //   .whitespace-nowrap { white-space: nowrap; }

    //   .th-light { background: #f3f4f6; color: #111827; }
    //   .th-dark { background: #374151; color: #ffffff; }

    //   .tr-base-light { background: #ffffff; }
    //   .tr-base-dark { background: #1f2937; }
    //   .tr-alt-light { background: #f9fafb; }
    //   .tr-alt-dark { background: #1e293b; }

    //   .pass { color: #059669; font-weight: bold;}
    //   .fail { color: #dc2626; font-weight: bold;}

    //   /* Header & Logo styling synced from Attendance */
    //   .header-block { border-bottom: 1px solid var(--border-color); padding-bottom: 12px; margin-bottom: 16px; }
    //   .org-container {
    //     display: grid;
    //     grid-template-columns: 1fr auto 1fr; /* 3 columns forces perfect centering */
    //     align-items: center;
    //     padding: 12px 16px;
    //     border: 1px solid var(--border-color);
    //     background: ${isLight ? '#f9fafb' : '#111827'};
    //     border-radius: 6px;
    //   }
    //   .org-logo { height: 50px; width: 50px; object-fit: contain; }
    //   .org-header { height: 50px; max-width: 400px; object-fit: contain; }

    //   h1 { margin: 0 0 8px 0; font-size: 18px; font-weight: bold; }
    //   .meta-info { display: flex; flex-wrap: wrap; gap: 14px 22px; font-size: 13px; }
    //   .meta-item { display: flex; gap: 6px; align-items: baseline; }
    //   .meta-label { color: ${isLight ? '#4b5563' : '#9ca3af'}; font-weight: bold; }

    //   .student-cell { display: flex; align-items: center; gap: 8px; text-align: left; }
    //   .student-column { text-align: left !important; white-space: nowrap; font-weight: 500;}
    //   .student-thumb { height: 32px; width: 32px; flex-shrink: 0; border: 1px solid var(--border-color); object-fit: contain; background-color: white; border-radius: 4px; }

    //   @media print {
    //     body { background: #fff !important; }
    //     .shell-dark, .shell-light { color: #000 !important; background: #fff !important; }
    //     .th-dark, .th-light { color: #000 !important; }
    //     table { break-inside: auto !important; page-break-inside: auto !important; }
    //     tr { break-inside: avoid !important; page-break-inside: avoid !important; page-break-after: auto !important; }
    //     td, th { break-inside: avoid !important; page-break-inside: avoid !important; }
    //     .report { padding: 12px !important; display: block !important; }
    //   }
    //   @page { size: ${preferences.pageSize} ${preferences.orientation}; margin: ${preferences.margin}mm; }
    // ''';

    // CSS synchronized with attendance_html_generator.dart
    final String embeddedCss = '''
      :root {
        --border-color: ${isLight ? '#d1d5db' : '#4b5563'};
      }
      * { box-sizing: border-box; -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
      html, body { margin: 0; padding: 0; font-family: Arial, sans-serif; background: #ffffff; }

      .report { font-size: 13px; padding: 24px; max-width: 100%; margin: 0 auto; }
      .shell-light { background: #ffffff; color: #111827; }
      .shell-dark { background: #1f2937; color: #f9fafb; }

      /* Table Width fix: 'auto' prevents horizontal stretching without breaking vertical pagination */
      table { border-collapse: collapse; width: auto; font-size: inherit; margin-top: 16px; }
      th, td { border: 1px solid var(--border-color); padding: 8px 12px; }
      th { text-align: center; font-weight: 600; }
      td { text-align: center; vertical-align: middle; }
      .whitespace-nowrap { white-space: nowrap; }

      .th-light { background: #f3f4f6; color: #111827; }
      .th-dark { background: #374151; color: #ffffff; }

      .tr-base-light { background: #ffffff; }
      .tr-base-dark { background: #1f2937; }
      .tr-alt-light { background: #f9fafb; }
      .tr-alt-dark { background: #1e293b; }

      .pass { color: #059669; font-weight: bold;}
      .fail { color: #dc2626; font-weight: bold;}

      /* Header & Logo styling synced from Attendance */
      .header-block { border-bottom: 1px solid var(--border-color); padding-bottom: 12px; margin-bottom: 16px; }
      .org-container {
        display: grid;
        grid-template-columns: 1fr auto 1fr; /* 3 columns forces perfect centering */
        align-items: center;
        padding: 12px 16px;
        border: 1px solid var(--border-color);
        background: ${isLight ? '#f9fafb' : '#111827'};
        border-radius: 6px;
      }
      .org-logo { height: 50px; width: 50px; object-fit: contain; }
      .org-header { height: 50px; max-width: 400px; object-fit: contain; }

      h1 { margin: 0 0 8px 0; font-size: 18px; font-weight: bold; }
      .meta-info { display: flex; flex-wrap: wrap; gap: 14px 22px; font-size: 13px; }
      .meta-item { display: flex; gap: 6px; align-items: baseline; }
      .meta-label { color: ${isLight ? '#4b5563' : '#9ca3af'}; font-weight: bold; }

      .student-cell { display: flex; align-items: center; gap: 8px; text-align: left; }
      .student-column { text-align: left !important; white-space: nowrap; font-weight: 500;}
      .student-thumb { height: 32px; width: 32px; flex-shrink: 0; border: 1px solid var(--border-color); object-fit: contain; background-color: white; border-radius: 4px; }

      @media print {
        body { background: #fff !important; }
        .shell-dark, .shell-light { color: #000 !important; background: #fff !important; }
        .th-dark, .th-light { color: #000 !important; }

        /* STRICT PAGINATION RULES FOR NATIVE PDF ENGINE */
        table { page-break-inside: auto !important; break-inside: auto !important; }
        tr { page-break-inside: avoid !important; break-inside: avoid !important; page-break-after: auto !important; }
        thead { display: table-header-group !important; }
        tbody { display: table-row-group !important; }
      }
      @page { size: ${preferences.pageSize} ${preferences.orientation}; margin: ${preferences.margin}mm; }
    ''';

    buffer.writeln('''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Exam Report</title>
        <style>$embeddedCss</style>
      </head>
      <body>
        <div class="report shell-$themePrefix">
    ''');

    // --- BRANDING HEADER ---
    if (orgLogoUrl != null || orgHeaderUrl != null) {
      buffer.writeln('<div class="header-block">');
      buffer.writeln('<div class="org-container">');

      // Left Col: Logo
      buffer.writeln(
        '<div style="display: flex; justify-content: flex-start; align-items: center;">',
      );
      if (orgLogoUrl != null) {
        buffer.writeln(
          '<img src="$orgLogoUrl" class="org-logo" alt="Organisation logo"/>',
        );
      }
      buffer.writeln('</div>');

      // Center Col: Header
      buffer.writeln(
        '<div style="display: flex; justify-content: center; align-items: center;">',
      );
      if (orgHeaderUrl != null) {
        buffer.writeln(
          '<img src="$orgHeaderUrl" class="org-header" alt="Organisation header"/>',
        );
      }
      buffer.writeln('</div>');

      // Right Col: Spacer for centering
      buffer.writeln('<div></div>');
      buffer.writeln('</div></div>');
    }

    // --- REPORT TITLE & META ---
    buffer.writeln('<h1>${_escapeHtml(reportTitle ?? "Exam Report")}</h1>');
    buffer.writeln('<div class="meta-info">');
    if (!preferences.isMultiExam) {
      buffer.writeln(
        '<div class="meta-item"><span class="meta-label">Subject:</span><span>${_escapeHtml(subjects.first.label)}</span></div>',
      );
    }
    buffer.writeln(
      '<div class="meta-item"><span class="meta-label">School:</span><span>PARIKSIT</span></div>',
    );
    buffer.writeln('</div>');

    // --- TABLE SECTION ---
    buffer.writeln('<table>');

    // --- THEAD ---
    buffer.writeln('<thead>');
    buffer.writeln('<tr class="th-$themePrefix">');
    buffer.writeln('<th rowspan="3">Sl. No.</th>');
    buffer.writeln('<th rowspan="3">Roll No.</th>');
    buffer.writeln('<th rowspan="3" class="student-column">Student</th>');
    buffer.writeln('<th rowspan="3">Class-Sec</th>');

    final examLabel =
        preferences.isMultiExam ? "Combined Exam Series" : "Subject Assessment";
    buffer.writeln('<th colspan="${subjects.length}">$examLabel</th>');

    if (preferences.showGrandTotal)
      buffer.writeln('<th rowspan="3">${withMax("Total", grandMax)}</th>');
    if (preferences.showOverallPercentage)
      buffer.writeln('<th rowspan="3">%</th>');
    if (preferences.showOverallRank)
      buffer.writeln('<th rowspan="3">Rank</th>');
    buffer.writeln('</tr>');

    // Date Header
    buffer.writeln(
      '<tr class="th-$themePrefix"><th colspan="${subjects.length}" style="font-weight: normal; color: ${isLight ? '#4b5563' : '#d1d5db'};">${_escapeHtml(examDateString ?? "N/A")}</th></tr>',
    );

    // Subject Headers
    buffer.writeln('<tr class="th-$themePrefix">');
    for (var sub in subjects) {
      buffer.writeln('<th>${withMax(sub.label, sub.maxMarks)}</th>');
    }
    buffer.writeln('</tr>');
    buffer.writeln('</thead>');

    // --- TBODY ---
    buffer.writeln('<tbody>');
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final isEven = i % 2 == 0;
      final rowClass = isEven ? "tr-base-$themePrefix" : "tr-alt-$themePrefix";

      buffer.writeln('<tr class="$rowClass">');
      buffer.writeln('<td>${i + 1}</td>');
      buffer.writeln('<td>${_escapeHtml(row.rollNo)}</td>');

      // Student Cell
      buffer.writeln('<td class="student-column"><div class="student-cell">');
      if (preferences.includeStudentPic && row.imageUrl != null) {
        buffer.writeln(
          '<img class="student-thumb" src="${row.imageUrl}" alt="" />',
        );
      }
      buffer.writeln('<span>${_escapeHtml(row.name)}</span></div></td>');

      buffer.writeln(
        '<td class="whitespace-nowrap">${_escapeHtml(row.className)}-${_escapeHtml(row.section)}</td>',
      );

      // Subject Marks with Gradient Logic
      for (var sub in subjects) {
        final mark = row.marks[sub.key] ?? 0;
        final pct = (mark / sub.maxMarks) * 100;

        String bgColor = 'transparent';
        if (pct >= 80)
          bgColor = isLight ? '#d1fae5' : 'rgba(16, 185, 129, 0.2)';
        else if (pct >= 40)
          bgColor = isLight ? '#fef08a' : 'rgba(245, 158, 11, 0.2)';
        else
          bgColor = isLight ? '#fecaca' : 'rgba(244, 63, 94, 0.2)';

        buffer.writeln(
          '<td style="background-color: $bgColor; font-weight: 500;">${mark.toStringAsFixed(0)}</td>',
        );
      }

      // Summary Columns
      if (preferences.showGrandTotal)
        buffer.writeln('<td>${row.total.toStringAsFixed(0)}</td>');
      if (preferences.showOverallPercentage) {
        final colorClass = row.isFail ? 'fail' : 'pass';
        buffer.writeln(
          '<td class="$colorClass">${row.percentage.toStringAsFixed(1)}%</td>',
        );
      }
      if (preferences.showOverallRank) buffer.writeln('<td>${row.rank}</td>');

      buffer.writeln('</tr>');
    }
    buffer.writeln('</tbody>');
    buffer.writeln('</table>');
    buffer.writeln('</div></body></html>');

    return buffer.toString();
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
