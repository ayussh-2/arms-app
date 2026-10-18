import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../widgets/arms_snackbar.dart';
import '../models/scorecard_models.dart';

class ScorecardPdfGenerator {
  /// Opens the native system PDF preview layout directly.
  /// From here, the user can immediately view pages, save as PDF, or share via apps.
  static Future<void> previewAndShareScorecardPdf({
    required BuildContext context,
    required StudentAcademicScorecard scorecard,
  }) async {
    try {
      final html = generateHtml(scorecard);
      final safeName = scorecard.student.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
      final title = '${safeName}_Academic_Scorecard_${scorecard.session.label}';

      await Printing.layoutPdf(
        name: title,
        format: PdfPageFormat.a4,
        onLayout: (PdfPageFormat format) async {
          // ignore: deprecated_member_use
          return await Printing.convertHtml(
            format: format,
            html: html,
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ArmsSnackbar.showError(context, 'Failed to preview/share PDF: $e');
      }
    }
  }

  /// Generates clean HTML report matching the ARMS web application reportCardMarkup format.
  static String generateHtml(StudentAcademicScorecard scorecard) {
    final student = scorecard.student;
    final session = scorecard.session;
    final overview = scorecard.overview;
    final attendance = scorecard.attendance;

    final orgName = student.organisationDisplayName ?? student.organisationName ?? 'Academic Management System';
    final orgLogo = student.organisationLogoUrl;

    // Count attended exams
    final attendedExams = scorecard.groups.fold<int>(
      0,
      (sum, g) => sum + g.exams.where((e) => e.percentage != null).length,
    );
    final totalExamsCount = scorecard.groups.fold<int>(
      0,
      (sum, g) => sum + g.exams.length,
    );

    final groupsHtml = StringBuffer();
    for (final group in scorecard.groups) {
      // Sort exams in group latest date first
      final sortedExams = [...group.exams]..sort((a, b) {
        final da = a.examDate ?? '';
        final db = b.examDate ?? '';
        final cmp = db.compareTo(da);
        return cmp != 0 ? cmp : b.examName.compareTo(a.examName);
      });

      final validExams = sortedExams.filter((e) => e.percentage != null).toList();
      final avgObt = validExams.isNotEmpty
          ? validExams.map((e) => e.obtained).reduce((a, b) => a + b) / validExams.length
          : null;
      final avgClass = sortedExams.where((e) => e.averageMarks != null).isNotEmpty
          ? sortedExams.where((e) => e.averageMarks != null).map((e) => e.averageMarks!).reduce((a, b) => a + b) / sortedExams.where((e) => e.averageMarks != null).length
          : null;

      groupsHtml.write('''
        <section class="group-block">
          <div class="group-title">${_escape(group.label)}</div>
          <div class="table-shell">
            <table>
              <thead>
                <tr>
                  <th style="width: 14%;">Date</th>
                  <th style="width: 34%; text-align: left;">Exam</th>
                  <th style="width: 16%;">Marks</th>
                  <th style="width: 14%;">Class Avg</th>
                  <th style="width: 10%;">Rank</th>
                  <th style="width: 12%;">%</th>
                </tr>
              </thead>
              <tbody>
      ''');

      for (final exam in sortedExams) {
        final pctStr = exam.percentage != null ? '${exam.percentage!.toStringAsFixed(2)}%' : '-';
        final rankStr = exam.rank != null ? '#${exam.rank}/${exam.participants}' : '-';
        final avgStr = exam.averageMarks != null ? exam.averageMarks!.toStringAsFixed(1) : '-';
        final marksLabel = '${exam.obtained.toStringAsFixed(exam.obtained % 1 == 0 ? 0 : 1)} / ${exam.maxMarks.toStringAsFixed(0)}';

        groupsHtml.write('''
          <tr>
            <td>${_escape(_formatDate(exam.examDate))}</td>
            <td class="label-cell"><strong>${_escape(exam.examName)}</strong></td>
            <td>$marksLabel</td>
            <td>$avgStr</td>
            <td>$rankStr</td>
            <td><strong>$pctStr</strong></td>
          </tr>
        ''');

        // Sub-rows if exam has multiple subjects
        if (exam.subjects.length > 1) {
          for (final sub in exam.subjects) {
            final subPct = sub.percentage != null ? '${sub.percentage!.toStringAsFixed(2)}%' : '-';
            final subRank = sub.rank != null ? '#${sub.rank}' : '-';
            final subObt = sub.obtained != null ? sub.obtained!.toStringAsFixed(sub.obtained! % 1 == 0 ? 0 : 1) : '-';
            final subMax = sub.maxMarks.toStringAsFixed(0);
            final subAvg = sub.averageMarks != null ? sub.averageMarks!.toStringAsFixed(1) : '-';

            groupsHtml.write('''
              <tr class="sub-row">
                <td></td>
                <td class="label-cell" style="padding-left: 20px;">↳ ${_escape(sub.subjectName)}</td>
                <td>$subObt / $subMax</td>
                <td>$subAvg</td>
                <td>$subRank</td>
                <td>$subPct</td>
              </tr>
            ''');
          }
        }
      }

      // Group Average Row matching web app
      final groupAvgPctStr = group.averagePercentage != null ? '${group.averagePercentage!.toStringAsFixed(2)}%' : '-';
      final groupAvgMarksStr = avgObt != null ? avgObt.toStringAsFixed(1) : '-';
      final groupClassAvgStr = avgClass != null ? avgClass.toStringAsFixed(1) : '-';

      groupsHtml.write('''
              <tr class="average-row">
                <td colspan="2" class="label-cell"><strong>Average</strong></td>
                <td><strong>$groupAvgMarksStr</strong></td>
                <td>$groupClassAvgStr</td>
                <td>-</td>
                <td><strong>$groupAvgPctStr</strong></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
      ''');
    }

    // Remarks
    final commentsHtml = StringBuffer();
    if (scorecard.comments.isNotEmpty) {
      commentsHtml.write('''
        <section class="section-block">
          <div class="section-title">Remarks History</div>
          <div class="comments-list">
      ''');
      for (final c in scorecard.comments) {
        commentsHtml.write('''
          <div class="comment-item">
            <div class="comment-meta">
              <strong>${_escape(c.authorName)} (${_escape(c.authorType.toUpperCase())})</strong>
              <span>${_escape(_formatDate(c.createdAt))}</span>
            </div>
            <p>${_escape(c.commentText)}</p>
          </div>
        ''');
      }
      commentsHtml.write('</div></section>');
    }

    // Tags
    final tagsHtml = StringBuffer();
    if (scorecard.tags.isNotEmpty) {
      tagsHtml.write('<div style="margin-top: 8px;">');
      for (final tag in scorecard.tags) {
        tagsHtml.write('<span class="tag-chip">${_escape(tag)}</span>');
      }
      tagsHtml.write('</div>');
    }

    final rankDisplay = overview.overallRank != null
        ? (overview.totalParticipants != null && overview.totalParticipants! > 0
            ? '#${overview.overallRank!.toInt()} / ${overview.totalParticipants}'
            : '#${overview.overallRank!.toInt()}')
        : '-';
    final pctDisplay = overview.overallPercentage != null ? '${overview.overallPercentage!.toStringAsFixed(2)}%' : '-';
    final marksDisplay = '${overview.overallObtained.toStringAsFixed(0)} / ${overview.overallMaxMarks.toStringAsFixed(0)}';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${_escape(student.name)} Scorecard</title>
  <style>
    :root {
      --ink: #0f172a;
      --muted: #475569;
      --line: #cbd5e1;
      --soft: #eef4ff;
      --title: #153e75;
      --bar: #123b7a;
    }
    @page {
      size: A4 portrait;
      margin: 8mm;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 0;
      background: white;
      color: var(--ink);
      font-family: Arial, Helvetica, sans-serif;
      font-size: 11px;
      line-height: 1.35;
    }
    .report {
      width: 100%;
    }
    .card-inner {
      padding: 4px;
    }
    .header-grid {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
    }
    .logo-box {
      height: 68px;
      max-width: 120px;
    }
    .logo-box img {
      max-height: 68px;
      max-width: 120px;
      object-fit: contain;
    }
    .org-block {
      flex: 1;
      text-align: center;
    }
    .org-name {
      font-size: 20px;
      font-weight: 800;
      color: #0f3d82;
      letter-spacing: 0.04em;
      margin: 0;
    }
    .report-bar {
      margin-top: 10px;
      border-radius: 8px;
      background: linear-gradient(90deg, #0f3d82 0%, #2457a7 100%);
      color: white;
      text-align: center;
      font-size: 18px;
      font-weight: 800;
      letter-spacing: 0.12em;
      padding: 6px 14px;
    }
    .report-header-row {
      margin-top: 4px;
      text-align: center;
    }
    .report-header-chip {
      display: inline-block;
      border-radius: 8px;
      background: linear-gradient(90deg, #0f3d82 0%, #2457a7 100%);
      color: #ffffff;
      font-size: 11px;
      font-weight: 700;
      padding: 4px 14px;
    }
    .meta-block {
      margin-top: 12px;
      border: 1px solid #dbe7f5;
      border-radius: 12px;
      background: linear-gradient(180deg, #eaf2ff 0%, #dce9ff 100%);
      padding: 12px 16px;
    }
    .meta-grid {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 16px;
    }
    .student-name {
      font-size: 18px;
      font-weight: 800;
      color: #0f172a;
      margin-bottom: 4px;
    }
    .student-meta-line {
      font-size: 11px;
      color: #334155;
      font-weight: 600;
      margin-top: 2px;
    }
    .passport-photo {
      width: 75px;
      height: 95px;
      border: 2px solid #000000;
      border-radius: 6px;
      overflow: hidden;
      background: white;
      flex-shrink: 0;
    }
    .passport-photo img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .overall-summary {
      margin-top: 12px;
      border-radius: 10px;
      background: linear-gradient(180deg, #eff6ff 0%, #dbeafe 100%);
      border: 1px solid #bfdbfe;
      padding: 10px 14px;
    }
    .overall-summary-title {
      color: #1e3a8a;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }
    .overall-summary-text {
      margin-top: 4px;
      font-size: 12px;
      font-weight: 700;
      color: #1f2937;
    }
    .group-block {
      margin-top: 14px;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .group-title {
      border: 1px solid var(--line);
      border-bottom: 0;
      border-radius: 8px 8px 0 0;
      background: linear-gradient(90deg, #0f3d82 0%, #2457a7 100%);
      text-align: center;
      color: #ffffff;
      font-size: 13px;
      font-weight: 800;
      letter-spacing: 0.04em;
      padding: 6px 12px;
    }
    .table-shell {
      border: 1px solid var(--line);
      border-radius: 0 0 8px 8px;
      overflow: hidden;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 10px;
    }
    th, td {
      border: 1px solid var(--line);
      padding: 5px 6px;
      text-align: center;
      vertical-align: middle;
    }
    th {
      background: #e9f1ff;
      color: #163a6b;
      font-weight: 800;
    }
    td.label-cell {
      text-align: left;
    }
    .sub-row td {
      background: #fafafa;
      color: #475569;
      font-size: 9.5px;
    }
    .average-row td {
      background: #eef4ff;
      color: #111827;
      font-weight: 700;
    }
    .attendance-box {
      margin-top: 12px;
      background: #f0fdf4;
      border: 1px solid #bbf7d0;
      border-radius: 8px;
      padding: 8px 12px;
      font-size: 10.5px;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .section-block {
      margin-top: 12px;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .section-title {
      font-size: 12px;
      font-weight: 800;
      color: #153e75;
      border-bottom: 1px solid #cbd5e1;
      padding-bottom: 4px;
      margin-bottom: 6px;
    }
    .comment-item {
      border-left: 3px solid #0051d5;
      padding-left: 8px;
      margin-bottom: 6px;
    }
    .comment-meta {
      font-size: 9px;
      color: #64748b;
      display: flex;
      justify-content: space-between;
    }
    .comment-item p {
      margin: 2px 0 0 0;
      font-size: 10px;
    }
    .tag-chip {
      display: inline-block;
      background: #eff6ff;
      color: #1d4ed8;
      border: 1px solid #bfdbfe;
      border-radius: 10px;
      padding: 2px 8px;
      font-size: 9px;
      margin-right: 4px;
    }
    .footer {
      margin-top: 18px;
      border-top: 1px solid #cbd5e1;
      padding-top: 6px;
      font-size: 8.5px;
      color: #94a3b8;
      display: flex;
      justify-content: space-between;
    }
    @media print {
      body { background: white; }
      .group-block { break-inside: avoid; page-break-inside: avoid; }
      .meta-block { break-inside: avoid; page-break-inside: avoid; }
      .overall-summary { break-inside: avoid; page-break-inside: avoid; }
    }
  </style>
</head>
<body>
  <div class="report">
    <div class="card-inner">
      <div class="header-grid">
        ${orgLogo != null && orgLogo.isNotEmpty ? '<div class="logo-box"><img src="$orgLogo"></div>' : '<div style="width: 40px;"></div>'}
        <div class="org-block">
          <h1 class="org-name">${_escape(orgName.toUpperCase())}</h1>
        </div>
        <div style="width: 40px;"></div>
      </div>

      <div class="report-bar">ACADEMIC JOURNEY</div>
      <div class="report-header-row">
        <div class="report-header-chip">${_escape(session.label)} Academic Session</div>
      </div>

      <div class="meta-block">
        <div class="meta-grid">
          <div>
            <div class="student-name">${_escape(student.name)}</div>
            <div class="student-meta-line"><strong>Roll No:</strong> ${student.rollNo ?? '-'}</div>
            <div class="student-meta-line"><strong>School:</strong> ${_escape(student.schoolName ?? '-')}</div>
            <div class="student-meta-line"><strong>Class:</strong> ${_escape(student.className ?? '-')}${student.sectionName != null ? ' (${student.sectionName})' : ''}</div>
            <div class="student-meta-line"><strong>Exams:</strong> $attendedExams / $totalExamsCount</div>
            $tagsHtml
          </div>
          ${student.imageUrl != null && student.imageUrl!.isNotEmpty ? '<div class="passport-photo"><img src="${student.imageUrl}"></div>' : ''}
        </div>
      </div>

      <div class="overall-summary">
        <div class="overall-summary-title">Overall Performance</div>
        <div class="overall-summary-text">
          Overall marks: <strong>$marksDisplay</strong> &nbsp;|&nbsp;
          Overall percentage: <strong>$pctDisplay</strong> &nbsp;|&nbsp;
          Overall rank: <strong>$rankDisplay</strong>
        </div>
      </div>

      $groupsHtml

      <div class="attendance-box">
        <strong>Attendance Overview:</strong> Attended <strong>${attendance.presentDays}</strong> out of <strong>${attendance.workingDays}</strong> working days (<strong>${attendance.percentage.toStringAsFixed(1)}%</strong>).
        Absents: <strong>${attendance.absentDays}</strong> | Approved Leaves: <strong>${attendance.leaveDays}</strong> | Holidays: <strong>${attendance.holidayDays}</strong>.
      </div>

      $commentsHtml

      <div class="footer">
        <span>Generated by ARMS Academic Management System</span>
        <span>Date: ${_formatDate(DateTime.now().toIso8601String().substring(0, 10))}</span>
      </div>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final trimmed = raw.trim();
    try {
      final dt = DateTime.parse(trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = (dt.year % 100).toString().padLeft(2, '0');
      return '$day $month $year';
    } catch (_) {
      return trimmed;
    }
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

extension _IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
