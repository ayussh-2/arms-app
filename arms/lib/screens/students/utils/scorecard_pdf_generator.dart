import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/arms_snackbar.dart';
import '../models/scorecard_models.dart';

class ScorecardPdfGenerator {
  /// Calls the Next.js server to generate a pixel-perfect Puppeteer report card PDF,
  /// downloads the generated PDF from Cloudflare R2, and opens the native system preview/print dialog.
  static Future<void> previewAndShareScorecardPdf({
    required BuildContext context,
    required StudentAcademicScorecard scorecard,
    String? organisationId,
    String? mode,
  }) async {
    try {
      final endpoint = Uri.parse(AppConstants.scorecardPdfApiEndpoint);
      final effectiveOrgId = organisationId?.isNotEmpty == true
          ? organisationId
          : scorecard.student.organisationDisplayName;

      final requestBody = jsonEncode({
        'studentId': scorecard.student.id,
        if (effectiveOrgId != null && effectiveOrgId.isNotEmpty)
          'organisationId': effectiveOrgId,
        'sessionYear': scorecard.session.selectedSessionYear,
        'mode': mode ?? 'series',
      });

      final response = await http
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        String errorMsg = 'Failed to generate PDF (${response.statusCode})';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson is Map && errJson['error'] != null) {
            errorMsg = errJson['error'].toString();
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pdfUrl = data['url'] as String?;
      final filename = data['filename'] as String? ??
          '${scorecard.student.name}_scorecard.pdf';

      if (pdfUrl == null || pdfUrl.isEmpty) {
        throw Exception('Server did not return a valid PDF URL.');
      }

      // Download the PDF from the R2 public CDN URL
      final pdfResponse = await http
          .get(Uri.parse(pdfUrl))
          .timeout(const Duration(seconds: 45));

      if (pdfResponse.statusCode != 200 || pdfResponse.bodyBytes.isEmpty) {
        throw Exception(
          'Failed to download scorecard PDF from CDN (${pdfResponse.statusCode})',
        );
      }

      final pdfBytes = pdfResponse.bodyBytes;

      // 1. Open native system print & save preview dialog
      await Printing.layoutPdf(
        name: filename,
        format: PdfPageFormat.a4,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );

      // 2. Open Android native share dialog to share to other apps (WhatsApp, Gmail, etc.)
      await Future.delayed(const Duration(milliseconds: 350));
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: filename,
        subject: '${scorecard.student.name} Report Card (${scorecard.session.label})',
      );
    } catch (e) {
      if (context.mounted) {
        ArmsSnackbar.showError(context, 'PDF Generation Error: $e');
      }
    }
  }
}
