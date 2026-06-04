import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import "../core/utils/exam_html_generator.dart";

class ExamReportDemoScreen extends StatefulWidget {
  const ExamReportDemoScreen({super.key});

  @override
  State<ExamReportDemoScreen> createState() => _ExamReportDemoScreenState();
}

class _ExamReportDemoScreenState extends State<ExamReportDemoScreen> {
  // --- Form State & Preferences ---
  ExamReportPreferences _prefs = ExamReportPreferences();
  bool _isExporting = false;

  // --- Dummy Data Lookups ---
  final String _logoUrl =
      "https://pub-e9087294b3954d9b8d998b0d98e990ad.r2.dev/PARIKSIT/branding/logo-1778301127097.jpg";
  final String _headerUrl =
      "https://pub-e9087294b3954d9b8d998b0d98e990ad.r2.dev/PARIKSIT/branding/header-1778486029070.png";

  // --- Single Exam Mock Data ---
  final List<SubjectColumn> _singleSubject = [
    SubjectColumn(key: 'MATH', label: 'MATH', maxMarks: 45),
  ];

  final List<StudentMarkRow> _singleExamData = [
    StudentMarkRow(
      rollNo: '2029085',
      name: 'PRISHA SHARMA',
      className: '10',
      section: 'C',
      imageUrl: 'https://picsum.photos/50?1',
      marks: {'MATH': 40},
      total: 40,
      percentage: 88.89,
      rank: 5,
      isFail: false,
    ),
    StudentMarkRow(
      rollNo: '2029086',
      name: 'ASMIT ROUTRAY',
      className: '10',
      section: 'C',
      imageUrl: 'https://picsum.photos/50?2',
      marks: {'MATH': 7},
      total: 7,
      percentage: 15.56,
      rank: 20,
      isFail: true,
    ),
    StudentMarkRow(
      rollNo: '2029090',
      name: 'NIRLIPTA DASH',
      className: '10',
      section: 'C',
      imageUrl: 'https://picsum.photos/50?3',
      marks: {'MATH': 37},
      total: 37,
      percentage: 82.22,
      rank: 11,
      isFail: false,
    ),
  ];

  // --- Multi Exam Mock Data ---
  final List<SubjectColumn> _multiSubjects = [
    SubjectColumn(key: 'PHY', label: 'PHY', maxMarks: 100),
    SubjectColumn(key: 'CHEM', label: 'CHEM', maxMarks: 100),
    SubjectColumn(key: 'MATH', label: 'MATH', maxMarks: 100),
  ];

  final List<StudentMarkRow> _multiExamData = [
    StudentMarkRow(
      rollNo: '2028157',
      name: 'BINAYAK LENKA',
      className: '11',
      section: 'A1',
      imageUrl: 'https://picsum.photos/50?4',
      marks: {'PHY': 19, 'CHEM': 3, 'MATH': 47},
      total: 69,
      percentage: 23.00,
      rank: 3,
      isFail: true,
    ),
    StudentMarkRow(
      rollNo: '2028190',
      name: 'AYUSHMAN DHAL',
      className: '11',
      section: 'A1',
      imageUrl: 'https://picsum.photos/50?5',
      marks: {'PHY': 37, 'CHEM': 17, 'MATH': 32},
      total: 86,
      percentage: 28.67,
      rank: 2,
      isFail: true,
    ),
    StudentMarkRow(
      rollNo: '2028226',
      name: 'SASWAT SAHOO',
      className: '11',
      section: 'A1',
      imageUrl: 'https://picsum.photos/50?6',
      marks: {'PHY': 19, 'CHEM': 24, 'MATH': 66},
      total: 109,
      percentage: 36.33,
      rank: 1,
      isFail: false,
    ),
  ];

  Future<void> _generateAndPrintPdf() async {
    setState(() => _isExporting = true);

    try {
      // 1. Select the correct data based on the Multi-Exam toggle
      final rows = _prefs.isMultiExam ? _multiExamData : _singleExamData;
      final subjects = _prefs.isMultiExam ? _multiSubjects : _singleSubject;
      final title =
          _prefs.isMultiExam
              ? "PTS - 02 - JEE - EB Report"
              : "10TH G3 CCT-2 MATHS Report";
      final dateStr = _prefs.isMultiExam ? "17-MAY-2026" : "27-APR-2026";

      // 2. Generate HTML String using your Generator Class
      final htmlContent = ExamHtmlGenerator.generateHtml(
        rows: rows,
        subjects: subjects,
        preferences: _prefs,
        orgLogoUrl: _logoUrl,
        orgHeaderUrl: _headerUrl,
        reportTitle: title,
        examDateString: dateStr,
      );

      // 3. Trigger the Native Device Print/Share Dialog
       await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final targetFormat = _prefs.orientation == 'landscape' ? format.landscape : format;
          return await Printing.convertHtml(format: targetFormat, html: htmlContent);
        },
        name: title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Export Exam Report',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: "DATA MODE",
              children: [
                _buildToggleRow(
                  'Multi-Exam Mode',
                  _prefs.isMultiExam,
                  (v) => setState(() => _prefs = _prefs.copyWith(isMultiExam: v)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "COLUMNS & DISPLAY CONFIG",
              children: [
                _buildToggleRow(
                  'Include Student Picture',
                  _prefs.includeStudentPic,
                  (v) => setState(() => _prefs = _prefs.copyWith(includeStudentPic: v)),
                ),
                _buildToggleRow(
                  'Show Max Marks',
                  _prefs.showMaxMarks,
                  (v) => setState(() => _prefs = _prefs.copyWith(showMaxMarks: v)),
                ),
                _buildToggleRow(
                  'Grand Total',
                  _prefs.showGrandTotal,
                  (v) => setState(() => _prefs = _prefs.copyWith(showGrandTotal: v)),
                ),
                _buildToggleRow(
                  'Overall Percentage',
                  _prefs.showOverallPercentage,
                  (v) => setState(() => _prefs = _prefs.copyWith(showOverallPercentage: v)),
                ),
                _buildToggleRow(
                  'Overall Rank',
                  _prefs.showOverallRank,
                  (v) => setState(() => _prefs = _prefs.copyWith(showOverallRank: v)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isExporting ? null : _generateAndPrintPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isExporting
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Generate PDF',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: val,
            activeColor: Colors.blueAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
