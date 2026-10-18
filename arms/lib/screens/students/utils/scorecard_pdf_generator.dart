import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../widgets/arms_snackbar.dart';
import '../models/scorecard_models.dart';

class ScorecardPdfGenerator {
  static Future<void> shareScorecardPdf({
    required BuildContext context,
    required StudentAcademicScorecard scorecard,
  }) async {
    try {
      final html = generateHtml(scorecard);
      // ignore: deprecated_member_use
      final bytes = await Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: html,
      );

      final safeName = scorecard.student.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
      final filename = '${safeName}_Academic_Scorecard_${scorecard.session.label}.pdf';

      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    } catch (e) {
      if (context.mounted) {
        ArmsSnackbar.showError(context, 'Failed to share scorecard PDF: $e');
      }
    }
  }

  static String generateHtml(StudentAcademicScorecard scorecard) {
    final student = scorecard.student;
    final session = scorecard.session;
    final overview = scorecard.overview;
    final attendance = scorecard.attendance;

    final orgName = student.organisationDisplayName ?? student.organisationName ?? 'Academic Management System';
    final orgLogo = student.organisationLogoUrl;

    final groupsHtml = StringBuffer();
    for (final group in scorecard.groups) {
      groupsHtml.write('''
        <div class="group-section">
          <div class="group-header">
            <h4>${_escape(group.label)}</h4>
            ${group.averagePercentage != null ? '<span class="group-badge">Avg: ${group.averagePercentage!.toStringAsFixed(1)}%</span>' : ''}
          </div>
          <table class="exam-table">
            <thead>
              <tr>
                <th style="width: 15%;">Date</th>
                <th style="width: 35%;">Exam Name</th>
                <th style="width: 12%;">Obtained</th>
                <th style="width: 12%;">Max</th>
                <th style="width: 12%;">Class Avg</th>
                <th style="width: 7%;">Rank</th>
                <th style="width: 7%;">%</th>
              </tr>
            </thead>
            <tbody>
      ''');

      for (final exam in group.exams) {
        final pctStr = exam.percentage != null ? '${exam.percentage!.toStringAsFixed(1)}%' : '-';
        final rankStr = exam.rank != null ? '#${exam.rank}' : '-';
        final avgStr = exam.averageMarks != null ? exam.averageMarks!.toStringAsFixed(1) : '-';

        groupsHtml.write('''
          <tr>
            <td>${_escape(_formatDate(exam.examDate))}</td>
            <td><strong>${_escape(exam.examName)}</strong></td>
            <td>${exam.obtained.toStringAsFixed(1)}</td>
            <td>${exam.maxMarks.toStringAsFixed(0)}</td>
            <td>$avgStr</td>
            <td>$rankStr</td>
            <td><strong>$pctStr</strong></td>
          </tr>
        ''');

        // If exam has multiple subjects, display breakdown sub-rows
        if (exam.subjects.length > 1) {
          for (final sub in exam.subjects) {
            final subPct = sub.percentage != null ? '${sub.percentage!.toStringAsFixed(1)}%' : '-';
            final subRank = sub.rank != null ? '#${sub.rank}' : '-';
            final subObt = sub.obtained != null ? sub.obtained!.toStringAsFixed(1) : '-';
            groupsHtml.write('''
              <tr class="sub-row">
                <td></td>
                <td style="padding-left: 20px;">↳ ${_escape(sub.subjectName)}</td>
                <td>$subObt</td>
                <td>${sub.maxMarks.toStringAsFixed(0)}</td>
                <td>${sub.averageMarks?.toStringAsFixed(1) ?? '-'}</td>
                <td>$subRank</td>
                <td>$subPct</td>
              </tr>
            ''');
          }
        }
      }

      groupsHtml.write('''
            </tbody>
          </table>
        </div>
      ''');
    }

    final commentsHtml = StringBuffer();
    if (scorecard.comments.isNotEmpty) {
      commentsHtml.write('''
        <div class="section-box">
          <h3>Remarks & Remarks History</h3>
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
      commentsHtml.write('</div></div>');
    }

    final tagsHtml = StringBuffer();
    if (scorecard.tags.isNotEmpty) {
      tagsHtml.write('<div class="tags-container">');
      for (final tag in scorecard.tags) {
        tagsHtml.write('<span class="tag-pill">${_escape(tag)}</span>');
      }
      tagsHtml.write('</div>');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${_escape(student.name)} Scorecard</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm 15mm;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1e293b;
      margin: 0;
      padding: 0;
      font-size: 11pt;
      line-height: 1.4;
    }
    .header-table {
      width: 100%;
      border-bottom: 2px solid #0051d5;
      padding-bottom: 12px;
      margin-bottom: 16px;
    }
    .org-title {
      font-size: 18pt;
      font-weight: bold;
      color: #0051d5;
      margin: 0;
    }
    .doc-title {
      font-size: 13pt;
      font-weight: 600;
      color: #475569;
      margin: 4px 0 0 0;
    }
    .session-badge {
      display: inline-block;
      background: #eff6ff;
      color: #0051d5;
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 9pt;
      font-weight: bold;
      margin-top: 4px;
    }
    .student-card {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 12px 16px;
      margin-bottom: 16px;
    }
    .student-grid {
      width: 100%;
      border-collapse: collapse;
    }
    .student-grid td {
      padding: 3px 0;
      font-size: 10.5pt;
    }
    .kpi-row {
      display: flex;
      gap: 12px;
      margin-bottom: 16px;
    }
    .kpi-box {
      flex: 1;
      background: #f1f5f9;
      border-radius: 6px;
      padding: 10px;
      text-align: center;
    }
    .kpi-value {
      font-size: 14pt;
      font-weight: bold;
      color: #0051d5;
      margin-bottom: 2px;
    }
    .kpi-label {
      font-size: 8.5pt;
      text-transform: uppercase;
      color: #64748b;
      letter-spacing: 0.5px;
    }
    .group-section {
      margin-bottom: 18px;
      page-break-inside: avoid;
    }
    .group-header {
      background: #f1f5f9;
      padding: 6px 10px;
      border-radius: 4px;
      margin-bottom: 6px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .group-header h4 {
      margin: 0;
      color: #0f172a;
      font-size: 11pt;
    }
    .group-badge {
      font-size: 9pt;
      color: #059669;
      font-weight: 600;
    }
    .exam-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 9.5pt;
    }
    .exam-table th {
      background: #f8fafc;
      border-bottom: 1px solid #cbd5e1;
      padding: 6px 8px;
      text-align: left;
      font-weight: 600;
      color: #475569;
    }
    .exam-table td {
      border-bottom: 1px solid #f1f5f9;
      padding: 6px 8px;
    }
    .sub-row td {
      font-size: 8.5pt;
      color: #64748b;
      background: #fafafa;
    }
    .attendance-box {
      background: #f0fdf4;
      border: 1px solid #bbf7d0;
      border-radius: 6px;
      padding: 10px 14px;
      margin-bottom: 16px;
      font-size: 10pt;
      page-break-inside: avoid;
    }
    .section-box {
      margin-top: 14px;
      page-break-inside: avoid;
    }
    .section-box h3 {
      font-size: 11pt;
      color: #0f172a;
      border-bottom: 1px solid #e2e8f0;
      padding-bottom: 4px;
      margin-bottom: 8px;
    }
    .comment-item {
      border-left: 3px solid #0051d5;
      padding-left: 10px;
      margin-bottom: 10px;
    }
    .comment-meta {
      font-size: 8.5pt;
      color: #64748b;
      display: flex;
      justify-content: space-between;
    }
    .comment-item p {
      margin: 2px 0 0 0;
      font-size: 9.5pt;
    }
    .tag-pill {
      display: inline-block;
      background: #eff6ff;
      color: #1d4ed8;
      border: 1px solid #bfdbfe;
      border-radius: 12px;
      padding: 2px 8px;
      font-size: 8.5pt;
      margin-right: 6px;
      margin-bottom: 4px;
    }
    .footer {
      margin-top: 24px;
      border-top: 1px solid #e2e8f0;
      padding-top: 8px;
      font-size: 8pt;
      color: #94a3b8;
      display: flex;
      justify-content: space-between;
    }
  </style>
</head>
<body>
  <table class="header-table">
    <tr>
      <td>
        <h1 class="org-title">${_escape(orgName)}</h1>
        <div class="doc-title">Academic Journey Scorecard</div>
        <div class="session-badge">Session: ${_escape(session.label)} (${_escape(session.fromDate)} to ${_escape(session.toDate)})</div>
      </td>
      ${orgLogo != null && orgLogo.isNotEmpty ? '<td align="right" style="vertical-align: top;"><img src="$orgLogo" style="height: 60px; max-width: 140px; object-fit: contain;"></td>' : ''}
    </tr>
  </table>

  <div class="student-card">
    <table class="student-grid">
      <tr>
        <td style="width: 50%;"><strong>Student Name:</strong> ${_escape(student.name)}</td>
        <td style="width: 50%;"><strong>Roll Number:</strong> ${student.rollNo ?? '-'}</td>
      </tr>
      <tr>
        <td><strong>Class & Section:</strong> ${_escape(student.className ?? '-')}${student.sectionName != null ? ' (${student.sectionName})' : ''}</td>
        <td><strong>School / Campus:</strong> ${_escape(student.schoolName ?? '-')}</td>
      </tr>
      ${student.fatherName != null && student.fatherName!.isNotEmpty ? '<tr><td colspan="2"><strong>Parent\'s Name:</strong> ${_escape(student.fatherName!)}</td></tr>' : ''}
    </table>
    $tagsHtml
  </div>

  <table style="width: 100%; border-collapse: separate; border-spacing: 8px 0; margin-bottom: 16px;">
    <tr>
      <td class="kpi-box" style="width: 25%;">
        <div class="kpi-value">${overview.overallObtained.toStringAsFixed(1)} / ${overview.overallMaxMarks.toStringAsFixed(0)}</div>
        <div class="kpi-label">Overall Marks</div>
      </td>
      <td class="kpi-box" style="width: 25%;">
        <div class="kpi-value">${overview.overallPercentage != null ? '${overview.overallPercentage!.toStringAsFixed(1)}%' : '-'}</div>
        <div class="kpi-label">Percentage</div>
      </td>
      <td class="kpi-box" style="width: 25%;">
        <div class="kpi-value">${overview.overallRank != null ? '#${overview.overallRank!.toInt()}' : '-'}</div>
        <div class="kpi-label">Class Rank</div>
      </td>
      <td class="kpi-box" style="width: 25%;">
        <div class="kpi-value">${attendance.percentage.toStringAsFixed(1)}%</div>
        <div class="kpi-label">Attendance (${attendance.presentDays}/${attendance.workingDays}d)</div>
      </td>
    </tr>
  </table>

  $groupsHtml

  <div class="attendance-box">
    <strong>Attendance Overview:</strong> Attended <strong>${attendance.presentDays}</strong> days out of <strong>${attendance.workingDays}</strong> working days (${attendance.percentage.toStringAsFixed(1)}%).
    Absents: <strong>${attendance.absentDays}</strong> | Approved Leaves: <strong>${attendance.leaveDays}</strong> | Institutional Holidays: <strong>${attendance.holidayDays}</strong>.
  </div>

  $commentsHtml

  <div class="footer">
    <span>Generated by ARMS Mobile Application</span>
    <span>Date: ${DateTime.now().toLocal().toString().split('.')[0]}</span>
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
