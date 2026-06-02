import 'package:flutter/material.dart' hide ThemeMode;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/attendance_html_generator.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // --- Form State ---
  DateTime _fromDate = DateTime(2026, 2, 1);
  DateTime _toDate = DateTime(2026, 2, 6);
  String _reportType = 'Absent + Present';
  AttendanceSession _session = AttendanceSession.morningIn;
  AttendanceSheetMode _mode = AttendanceSheetMode.combineByDay;
  String _school = 'All schools';
  String _class = 'All classes';
  String _section = 'All sections';

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
  String _searchQuery = '';

  // --- WebView State ---
  late final WebViewController _webViewController;
  String? _htmlContent;
  bool _isWebViewReady = false;

  // --- Mock Data ---
  final List<AttendanceSheetRow> _allMockRows = [
    AttendanceSheetRow(
      studentId: "1",
      rollNo: 2028001,
      studentName: "RUDRA NARAYAN RAUTA",
      schoolName: "DPS",
      className: "11",
      sectionName: "B",
      summary: "12 / 14 (85%)",
      statusesByDate: {
        "2026-02-06": AttendanceStatus.present,
        "2026-02-05": AttendanceStatus.absent,
      },
    ),
    AttendanceSheetRow(
      studentId: "2",
      rollNo: 2028002,
      studentName: "AHARSHI BASU",
      schoolName: "DAV",
      className: "11",
      sectionName: "A",
      summary: "14 / 14 (100%)",
      statusesByDate: {
        "2026-02-06": AttendanceStatus.present,
        "2026-02-05": AttendanceStatus.present,
      },
    ),
    AttendanceSheetRow(
      studentId: "3",
      rollNo: 2028003,
      studentName: "NAMRATA PADHI",
      schoolName: "PARIKSIT",
      className: "12",
      sectionName: "C",
      summary: "10 / 14 (71%)",
      statusesByDate: {
        "2026-02-06": AttendanceStatus.leave,
        "2026-02-05": AttendanceStatus.absent,
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize WebViewController once
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white);
  }

  // --- HTML Generation Logic ---
  void _generatePreview() {
    final preferences = AttendanceTemplatePreferences(
      theme: _isLightTheme ? ThemeMode.light : ThemeMode.dark,
      includeStudentPic: _includeStudentPic,
      showRollNo: _showRollNo,
      showSchool: _showSchool,
      showClassSection: _showClassSection,
      coloredStatus: _coloredStatus,
      showRemarks: _showRemarks,
      showHeader: true,
      showLogo: true,
      customHeaderText: "Monthly Attendance Report",
    );

    // 2. Filter the mock data AND inject the student image URL if the toggle is ON
    final filteredRows =
        _allMockRows
            .where((row) {
              if (_searchQuery.trim().isEmpty) return true;
              final query = _searchQuery.toLowerCase().trim();

              return row.studentName.toLowerCase().contains(query) ||
                  (row.rollNo?.toString().contains(query) ?? false) ||
                  row.schoolName.toLowerCase().contains(query) ||
                  row.className.toLowerCase().contains(query) ||
                  row.sectionName.toLowerCase().contains(query);
            })
            .map((row) {
              return AttendanceSheetRow(
                studentId: row.studentId,
                rollNo: row.rollNo,
                studentName: row.studentName,
                schoolName: row.schoolName,
                className: row.className,
                sectionName: row.sectionName,
                summary: row.summary,
                // INJECT IMAGE URL HERE BASED ON TOGGLE
                studentImageUrl:
                    _includeStudentPic
                        ? AppConstants.getStudentImageUrl(row.rollNo)
                        : null,
                statusesByDate: row.statusesByDate,
                sessionStatusesByDate: row.sessionStatusesByDate,
              );
            })
            .toList();

    // 3. Generate HTML with the Branding URLs included
    final generatedHtml = AttendanceHtmlGenerator.generateHtml(
      visibleRows: filteredRows,
      dateColumns: ["2026-02-06", "2026-02-05"],
      monthYearGroups: [
        MonthYearGroup(label: "Feb 2026", dates: ["2026-02-06", "2026-02-05"]),
      ],
      preferences: preferences,
      sheetMode: _mode,
      attendanceSessions: [_session],
      // PASS IN YOUR BRANDING URLS HERE
      orgLogoUrl: AppConstants.orgLogoUrl,
      orgHeaderUrl: AppConstants.orgHeaderUrl,
    );

    // 4. Update state and load HTML into WebView
    setState(() {
      _htmlContent = generatedHtml;
      _isWebViewReady = true;
    });

    _webViewController.loadHtmlString(generatedHtml);
  }

  Future<void> _exportPdf() async {
    if (_htmlContent == null) return;
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await Printing.convertHtml(format: format, html: _htmlContent!);
      },
      name: 'Attendance_Report',
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final initialDate = isFromDate ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // --- UI Builders ---
  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border.all(color: const Color(0xFF334155)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: const Color(0xFF1E293B),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: Colors.white70,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: onChanged,
              items:
                  items.map((T item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        item
                            .toString()
                            .split('.')
                            .last
                            .replaceAllMapped(
                              RegExp(r'([a-z])([A-Z])'),
                              (Match m) => '${m[1]} ${m[2]}',
                            ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime date, bool isFromDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectDate(context, isFromDate),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border.all(color: const Color(0xFF334155)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MM/dd/yyyy').format(date),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.blue.shade400 : const Color(0xFF334155),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.blue.shade100 : Colors.white70,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('Attendance Report'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          if (_isWebViewReady)
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text(
                'Export PDF',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: Column(
        children: [
          // --- FORM SECTION ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row Dropdowns
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 800 ? 8 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  children: [
                    _buildDatePicker('From Date', _fromDate, true),
                    _buildDatePicker('To Date', _toDate, false),
                    _buildDropdown(
                      'Report Type',
                      _reportType,
                      ['Absent + Present', 'Only Absentees', 'Only Present'],
                      (v) => setState(() => _reportType = v!),
                    ),
                    _buildDropdown(
                      'Sessions',
                      _session,
                      AttendanceSession.values,
                      (v) => setState(() => _session = v!),
                    ),
                    _buildDropdown(
                      'Mode',
                      _mode,
                      AttendanceSheetMode.values,
                      (v) => setState(() => _mode = v!),
                    ),
                    _buildDropdown('School', _school, [
                      'All schools',
                      'DPS',
                      'DAV',
                    ], (v) => setState(() => _school = v!)),
                    _buildDropdown('Class', _class, [
                      'All classes',
                      '11',
                      '12',
                    ], (v) => setState(() => _class = v!)),
                    _buildDropdown('Section', _section, [
                      'All sections',
                      'A',
                      'B',
                    ], (v) => setState(() => _section = v!)),
                  ],
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildToggleBtn(
                    'Include student pic',
                    _includeStudentPic,
                    () => setState(
                      () => _includeStudentPic = !_includeStudentPic,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'COLUMNS & STATUS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildToggleBtn(
                      'Roll no',
                      _showRollNo,
                      () => setState(() => _showRollNo = !_showRollNo),
                    ),
                    _buildToggleBtn(
                      'School',
                      _showSchool,
                      () => setState(() => _showSchool = !_showSchool),
                    ),
                    _buildToggleBtn(
                      'Class-Section',
                      _showClassSection,
                      () => setState(
                        () => _showClassSection = !_showClassSection,
                      ),
                    ),
                    _buildToggleBtn(
                      _isShortStatus ? 'P / A' : 'PRESENT / ABSENT',
                      _isShortStatus,
                      () => setState(() => _isShortStatus = !_isShortStatus),
                    ),
                    _buildToggleBtn(
                      'Colored status',
                      _coloredStatus,
                      () => setState(() => _coloredStatus = !_coloredStatus),
                    ),
                    _buildToggleBtn(
                      _isLightTheme ? 'Light Theme' : 'Dark Theme',
                      _isLightTheme,
                      () => setState(() => _isLightTheme = !_isLightTheme),
                    ),
                    _buildToggleBtn(
                      'Show holidays',
                      _showHolidays,
                      () => setState(() => _showHolidays = !_showHolidays),
                    ),
                    _buildToggleBtn(
                      'Show Sundays',
                      _showSundays,
                      () => setState(() => _showSundays = !_showSundays),
                    ),
                    _buildToggleBtn(
                      'Remove blank rows',
                      _removeBlankRows,
                      () =>
                          setState(() => _removeBlankRows = !_removeBlankRows),
                    ),
                    _buildToggleBtn(
                      'Remarks',
                      _showRemarks,
                      () => setState(() => _showRemarks = !_showRemarks),
                    ),
                    _buildToggleBtn(
                      'Hide unmarked days',
                      _hideUnmarkedDays,
                      () => setState(
                        () => _hideUnmarkedDays = !_hideUnmarkedDays,
                      ),
                    ),
                    _buildToggleBtn(
                      _datesDescending
                          ? 'Dates: Descending'
                          : 'Dates: Ascending',
                      _datesDescending,
                      () =>
                          setState(() => _datesDescending = !_datesDescending),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Search Input & Generate Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        onChanged: (val) {
                          // Save the query and instantly update the webview if it's already active
                          _searchQuery = val;
                          if (_isWebViewReady) {
                            _generatePreview();
                          }
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search student, roll, school, class, section',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF334155),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _generatePreview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Generate'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- WEBVIEW PREVIEW SECTION ---
          Expanded(
            child:
                _isWebViewReady
                    ? Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            _isLightTheme
                                ? Colors.white
                                : const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: WebViewWidget(controller: _webViewController),
                    )
                    : const Center(
                      child: Text(
                        'Configure parameters and tap Generate to preview.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
