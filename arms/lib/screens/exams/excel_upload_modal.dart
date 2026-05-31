import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel_plus/excel_plus.dart' hide Border;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

/// Modal for uploading Excel marks, column mapping, parsing, validation, and preview.
class ExcelMarksUploadModal extends StatefulWidget {
  final Map<String, dynamic> exam;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> schoolsLookup;
  final List<Map<String, dynamic>> classesLookup;
  final List<Map<String, dynamic>> sectionsLookup;

  const ExcelMarksUploadModal({
    super.key,
    required this.exam,
    required this.subjects,
    required this.students,
    required this.schoolsLookup,
    required this.classesLookup,
    required this.sectionsLookup,
  });

  @override
  State<ExcelMarksUploadModal> createState() => _ExcelMarksUploadModalState();
}

class _ExcelMarksUploadModalState extends State<ExcelMarksUploadModal> {
  // Mapping state
  final Map<String, String> _columnMapping = {
    'K': '',
    'L': '',
    'M': '',
    'N': '',
  };

  // File selection state
  File? _selectedFile;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  bool _isParsing = false;

  // Preview state
  Map<String, dynamic>? _excelPreview;

  // Collapsible sections in preview
  bool _showMissingRows = false;
  bool _showExtraRows = false;

  @override
  void initState() {
    super.initState();
    _autoMapColumns();
  }

  // Look up readable names from IDs
  String _lookupName(List<Map<String, dynamic>> lookup, String? id) {
    if (id == null) return 'N/A';
    final match = lookup.firstWhere(
      (item) => item['id']?.toString() == id.toString(),
      orElse: () => {},
    );
    return match['name']?.toString() ?? 'N/A';
  }

  Map<String, dynamic>? _findSubjectByName(String keyword) {
    final kw = keyword.toLowerCase();
    for (final s in widget.subjects) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      if (name.contains(kw)) return s;
    }
    return null;
  }

  // Auto-mapping K-N columns based on Series and Subjects
  void _autoMapColumns() {
    final seriesName = widget.exam['series']?['name']?.toString() ?? '';
    final isNeet = seriesName.toUpperCase().contains('NEET');
    final isJee = seriesName.toUpperCase().contains('JEE');

    final phy =
        _findSubjectByName('physics') ??
        (widget.subjects.isNotEmpty ? widget.subjects[0] : null);
    final chem =
        _findSubjectByName('chemistry') ??
        (widget.subjects.length > 1 ? widget.subjects[1] : null);
    final bio =
        _findSubjectByName('biology') ??
        _findSubjectByName('botany') ??
        _findSubjectByName('zoology');
    final math =
        _findSubjectByName('math') ??
        _findSubjectByName('mathematics') ??
        (widget.subjects.length > 2 ? widget.subjects[2] : null);

    setState(() {
      if (isNeet) {
        _columnMapping['K'] = phy?['id'] ?? '';
        _columnMapping['L'] = chem?['id'] ?? '';
        _columnMapping['M'] = bio?['id'] ?? ''; // Botany mapped to Biology
        _columnMapping['N'] = bio?['id'] ?? ''; // Zoology mapped to Biology
      } else if (isJee) {
        _columnMapping['K'] = phy?['id'] ?? '';
        _columnMapping['L'] = chem?['id'] ?? '';
        _columnMapping['M'] = math?['id'] ?? '';
        _columnMapping['N'] = '';
      } else {
        // Single subject
        if (widget.subjects.isNotEmpty) {
          _columnMapping['K'] = widget.subjects[0]['id'] ?? '';
        }
        _columnMapping['L'] = '';
        _columnMapping['M'] = '';
        _columnMapping['N'] = '';
      }
    });
  }

  // File Picker to select Excel import file
  Future<void> _pickExcelFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pickerResult = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (pickerResult == null) return;

      final fileRef = pickerResult.files.single;
      Uint8List? fileBytes = fileRef.bytes;

      if (fileBytes == null && fileRef.path != null) {
        final fileObj = File(fileRef.path!);
        fileBytes = fileObj.readAsBytesSync();
      }

      if (fileBytes == null) {
        throw Exception('Could not read file data. Please try again.');
      }

      setState(() {
        _selectedFileName = fileRef.name;
        _selectedFileBytes = fileBytes;
        if (fileRef.path != null) {
          _selectedFile = File(fileRef.path!);
        }
        _excelPreview = null; // Clear old preview
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: AppColors.errorText,
        ),
      );
    }
  }

  String _normalizeRollNo(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    return s;
  }

  // Parse Excel & Run validations matching web implementation rules
  void _parseExcelMarks() {
    if (_selectedFileBytes == null) return;

    setState(() => _isParsing = true);
    final messenger = ScaffoldMessenger.of(context);

    // Run in a delayed future to show loader transition
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        // 1. Column Mapping Validation
        bool hasAtLeastOneMapping = false;
        for (final val in _columnMapping.values) {
          if (val.isNotEmpty) hasAtLeastOneMapping = true;
        }

        if (!hasAtLeastOneMapping) {
          throw Exception(
            'Excel column mapping does not match the selected exam series. Map at least one column.',
          );
        }

        // For NEET series validation
        final seriesName = widget.exam['series']?['name']?.toString() ?? '';
        final isNeet = seriesName.toUpperCase().contains('NEET');
        if (isNeet) {
          final bioId =
              _findSubjectByName('biology')?['id'] ??
              _findSubjectByName('botany')?['id'] ??
              _findSubjectByName('zoology')?['id'] ??
              '';
          if (bioId.isNotEmpty) {
            final mapsBioTwice =
                _columnMapping['M'] == bioId && _columnMapping['N'] == bioId;
            if (!mapsBioTwice) {
              throw Exception(
                'For NEET, map four Excel columns to Physics, Chemistry, and Biology twice (Botany and Zoology)...',
              );
            }
          }
        }

        // 2. File Reading
        final excel = Excel.decodeBytes(_selectedFileBytes!);
        if (excel.tables.isEmpty) {
          throw Exception('No worksheet found in the uploaded file');
        }

        final sheetName = excel.tables.keys.first;
        final sheet = excel[sheetName];
        if (sheet.maxRows == 0) {
          throw Exception('No worksheet found in the uploaded file');
        }

        // 3. Header Validation
        final headerRow = sheet.rows[0];
        if (headerRow.length <= 2) {
          throw Exception('Column C header must be Roll No');
        }

        final colCValue =
            headerRow[2]?.value?.toString().trim().toLowerCase() ?? '';
        if (!colCValue.contains('roll no') && !colCValue.contains('rollno')) {
          throw Exception('Column C header must be Roll No');
        }

        final colIndices = {'K': 10, 'L': 11, 'M': 12, 'N': 13};
        for (final entry in _columnMapping.entries) {
          final colLetter = entry.key;
          final subjectId = entry.value;
          if (subjectId.isNotEmpty) {
            final colIdx = colIndices[colLetter]!;
            if (headerRow.length <= colIdx ||
                headerRow[colIdx] == null ||
                headerRow[colIdx]!.value == null ||
                headerRow[colIdx]!.value.toString().trim().isEmpty) {
              throw Exception('Expected score headers in column $colLetter');
            }
          }
        }

        // 4. Data Extraction & Validate Marks Ranges
        final List<Map<String, dynamic>> parsedMarks = [];
        final List<Map<String, dynamic>> extraRows = [];
        final List<Map<String, dynamic>> missingRows = [];
        final Set<String> parsedRollNos = {};

        // final mapped student marks data to apply back
        // studentId -> subjectId -> marks
        final Map<String, Map<String, String>> pendingStudentMarks = {};

        for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
          final row = sheet.rows[rowIndex];
          if (row.length <= 2) continue; // Skip empty rows

          final rollNoRaw = row[2]?.value?.toString();
          if (rollNoRaw == null || rollNoRaw.trim().isEmpty) continue;

          final rollNo = _normalizeRollNo(rollNoRaw);
          parsedRollNos.add(rollNo);
          final nameInExcel =
              row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';

          // Match student
          final student = widget.students.firstWhere(
            (s) => _normalizeRollNo(s['roll_no']?.toString()) == rollNo,
            orElse: () => {},
          );

          if (student.isEmpty) {
            extraRows.add({
              'rowNumber': rowIndex + 1,
              'rollNo': rollNo,
              'name': nameInExcel,
            });
            continue;
          }

          final studentId = student['id'] as String;
          pendingStudentMarks[studentId] = {};
          final Map<String, String> studentMarksMap = {};

          // Gather column marks by subjectId
          final Map<String, List<double>> subjectValues = {};

          for (final entry in _columnMapping.entries) {
            final colLetter = entry.key;
            final subjectId = entry.value;
            if (subjectId.isEmpty) continue;

            final colIdx = colIndices[colLetter]!;
            if (row.length <= colIdx) continue;

            final cellVal = row[colIdx]?.value?.toString().trim();
            if (cellVal == null || cellVal.isEmpty) continue;

            final numericVal = double.tryParse(cellVal);
            if (numericVal == null || !numericVal.isFinite) {
              throw Exception('Invalid marks found for roll no $rollNo');
            }

            final subject = widget.subjects.firstWhere(
              (sub) => sub['id'] == subjectId,
              orElse: () => {},
            );
            if (subject.isNotEmpty) {
              final maxMarks = (subject['max_marks'] as num? ?? 100).toDouble();
              final subjectName = subject['name'] ?? 'Subject';

              if (numericVal < -90) {
                throw Exception(
                  '$subjectName marks for roll no $rollNo cannot be below -90',
                );
              }

              if (numericVal > maxMarks) {
                throw Exception(
                  '$subjectName marks for roll no $rollNo exceed full marks ($maxMarks)',
                );
              }

              subjectValues.putIfAbsent(subjectId, () => []).add(numericVal);
            }
          }

          // Compute final marks
          for (final sub in widget.subjects) {
            final subId = sub['id'] as String;
            final maxMarks = (sub['max_marks'] as num? ?? 100).toDouble();
            final subName = sub['name'] ?? 'Subject';

            final vals = subjectValues[subId] ?? [];
            if (vals.isEmpty) continue;

            double totalVal = 0;
            for (final v in vals) {
              totalVal += v;
            }

            if (totalVal > maxMarks) {
              throw Exception(
                '$subName total marks ($totalVal) for roll no $rollNo exceed full marks ($maxMarks)',
              );
            }

            final String displayMark =
                (totalVal % 1 == 0)
                    ? totalVal.toInt().toString()
                    : totalVal.toString();
            studentMarksMap[subId] = displayMark;
            pendingStudentMarks[studentId]![subId] = displayMark;
          }

          parsedMarks.add({
            'rollNo': rollNo,
            'name': student['name'] ?? '',
            'marks': studentMarksMap,
          });
        }

        if (parsedMarks.isEmpty) {
          throw Exception('No uploaded roll numbers matched this student list');
        }

        // Identify missing students
        for (final student in widget.students) {
          final rollNo = _normalizeRollNo(student['roll_no']?.toString());
          if (!parsedRollNos.contains(rollNo)) {
            missingRows.add({'rollNo': rollNo, 'name': student['name'] ?? ''});
          }
        }

        setState(() {
          _excelPreview = {
            'requiredRows': widget.students.length,
            'derivedRows': parsedMarks.length,
            'missingRows': missingRows,
            'extraRows': extraRows,
            'parsedMarks': parsedMarks,
            'pendingStudentMarks': pendingStudentMarks,
          };
          _isParsing = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Excel parsing completed successfully. Matched ${parsedMarks.length} students!',
            ),
            backgroundColor: AppColors.successText,
          ),
        );
      } catch (e) {
        setState(() => _isParsing = false);
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                backgroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.errorText,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Validation Error',
                      style: AppTextStyles.headerSmall.copyWith(
                        color: AppColors.errorText,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  e.toString().replaceAll('Exception:', '').trim(),
                  style: AppTextStyles.bodyMedium,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'OK',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        );
      }
    });
  }

  // Returns selected student marks to main screen on confirmation
  void _confirmExcelImport() {
    if (_excelPreview == null) return;

    final pendingMarks =
        _excelPreview!['pendingStudentMarks']
            as Map<String, Map<String, String>>;
    Navigator.of(context).pop(pendingMarks);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLargeScreen = media.size.width > 700;

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: isLargeScreen ? 720 : media.size.width * 0.95,
        height: media.size.height * 0.85,
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _excelPreview == null
                            ? 'Import Marks from Excel'
                            : 'Import Preview & Validation',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: isLargeScreen ? 20 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _excelPreview == null
                            ? 'Select sheet.'
                            : 'Verify matching rows and parsed scores below before confirming.',
                        style: AppTextStyles.labelXs.copyWith(
                          fontSize: isLargeScreen ? 12 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMain),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Area
            Expanded(
              child:
                  _excelPreview == null
                      ? _buildUploadAndMappingStep()
                      : _buildPreviewStep(),
            ),
            const SizedBox(height: 12),

            // Actions Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_excelPreview == null) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 24 : 8),
                  ElevatedButton(
                    onPressed:
                        (_selectedFileBytes == null || _isParsing)
                            ? null
                            : _parseExcelMarks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 16 : 10,
                        vertical: isLargeScreen ? 12 : 8,
                      ),
                    ),
                    child:
                        _isParsing
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              'Parse & Preview',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ] else ...[
                  OutlinedButton(
                    onPressed: () => setState(() => _excelPreview = null),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 14 : 8,
                        vertical: isLargeScreen ? 12 : 8,
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 16 : 6),
                  ElevatedButton(
                    onPressed: _confirmExcelImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successText,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 16 : 10,
                        vertical: isLargeScreen ? 12 : 8,
                      ),
                    ),
                    child: Text(
                      'Confirm Import',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadAndMappingStep() {
    final isLarge = MediaQuery.of(context).size.width > 700;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Cards (Upload Excel File)
          _buildUploadCard(),
          const SizedBox(height: 16),

          // File name pill
          if (_selectedFileName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successText.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.successText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFileName!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.successText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Ready to parse',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.successText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // MAPPING CONFIGURATION SECTION
          Text(
            'Column Mapping Configuration'.toUpperCase(),
            style: AppTextStyles.labelXsUppercase.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Map Excel mark columns (K, L, M, N) to the subjects inside the exam setup:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Form Grid mapping
                if (isLarge) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildColumnDropdown('K', 'Physics/Marks'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildColumnDropdown('L', 'Chemistry')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildColumnDropdown('M', 'Math/Botany')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildColumnDropdown('N', 'Zoology')),
                    ],
                  ),
                ] else ...[
                  _buildColumnDropdown('K', 'Physics/Marks'),
                  const SizedBox(height: 12),
                  _buildColumnDropdown('L', 'Chemistry'),
                  const SizedBox(height: 12),
                  _buildColumnDropdown('M', 'Math/Botany'),
                  const SizedBox(height: 12),
                  _buildColumnDropdown('N', 'Zoology'),
                ],
                const SizedBox(height: 8),
                Text(
                  'Exam Series type detected: ${widget.exam['series']?['name'] ?? 'N/A'}',
                  style: AppTextStyles.labelXs.copyWith(
                    fontSize: isLarge ? 12 : 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnDropdown(String columnLetter, String helperLabel) {
    final mappedSubjectId = _columnMapping[columnLetter] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Column $columnLetter ($helperLabel)',
          style: AppTextStyles.labelXsUppercase.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withOpacity(0.5)),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:
                  widget.subjects.any((s) => s['id'] == mappedSubjectId)
                      ? mappedSubjectId
                      : '',
              isExpanded: true,
              onChanged: (newValue) {
                setState(() {
                  _columnMapping[columnLetter] = newValue ?? '';
                });
              },
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    'Disabled / Ignore Column',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                ...widget.subjects.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub['id'] as String,
                    child: Text(
                      sub['name'] as String? ?? 'Subject',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMain,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.file_upload_outlined,
                color: AppColors.textMain,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Upload Excel File',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickExcelFile,
              icon: const Icon(Icons.search, size: 16),
              label: Text(
                _selectedFileName == null
                    ? 'Browse Files...'
                    : 'Change File...',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Previews step showing statistics & matched students list
  Widget _buildPreviewStep() {
    if (_excelPreview == null) return const SizedBox();

    final requiredRows = _excelPreview!['requiredRows'] as int;
    final derivedRows = _excelPreview!['derivedRows'] as int;
    final missingRows = _excelPreview!['missingRows'] as List<dynamic>;
    final extraRows = _excelPreview!['extraRows'] as List<dynamic>;
    final parsedMarks = _excelPreview!['parsedMarks'] as List<dynamic>;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics row
          Row(
            children: [
              _buildStatCard(
                'REQUIRED',
                requiredRows.toString(),
                AppColors.primary,
                AppColors.primaryFaint,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'DERIVED',
                derivedRows.toString(),
                AppColors.successText,
                AppColors.successBg,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'MISSING',
                missingRows.length.toString(),
                AppColors.accent,
                AppColors.cardSurface,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'EXTRA',
                extraRows.length.toString(),
                AppColors.errorText,
                AppColors.errorBg,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Missing Rows warning section
          if (missingRows.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showMissingRows = !_showMissingRows),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Students missing from Excel (${missingRows.length})',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _showMissingRows
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                        ),
                      ],
                    ),
                    if (_showMissingRows) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: missingRows.length,
                        itemBuilder: (ctx, idx) {
                          final r = missingRows[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fiber_manual_record,
                                  size: 8,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    r['name'] ?? '',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Roll No: ${r['rollNo']}',
                                  style: AppTextStyles.labelXs.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Extra Rows in Excel section
          if (extraRows.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showExtraRows = !_showExtraRows),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorBg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.errorText.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.errorText,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Extra rows found in Excel (${extraRows.length}) - will be ignored',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.errorText,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _showExtraRows
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.errorText,
                        ),
                      ],
                    ),
                    if (_showExtraRows) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: extraRows.length,
                        itemBuilder: (ctx, idx) {
                          final r = extraRows[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fiber_manual_record,
                                  size: 8,
                                  color: AppColors.errorText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    r['name'] ?? 'Unknown Name',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 12,
                                      color: AppColors.errorText,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Roll No: ${r['rollNo']}',
                                  style: AppTextStyles.labelXs.copyWith(
                                    fontSize: 11,
                                    color: AppColors.errorText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // parsedMarks Table Preview
          Text(
            'Matched Student Scores Preview'.toUpperCase(),
            style: AppTextStyles.labelXsUppercase.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.cardSurface,
                  ),
                  columns: [
                    const DataColumn(
                      label: Text(
                        'Roll No',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ...widget.subjects.map(
                      (sub) => DataColumn(
                        label: Text(
                          '${sub['name']}\n(Max: ${sub['max_marks']})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  rows:
                      parsedMarks.map((studentRow) {
                        final rollNo = studentRow['rollNo'] as String;
                        final name = studentRow['name'] as String;
                        final marksMap =
                            studentRow['marks'] as Map<String, String>;

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                rollNo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(name, style: const TextStyle(fontSize: 12)),
                            ),
                            ...widget.subjects.map((sub) {
                              final subId = sub['id'] as String;
                              final score = marksMap[subId] ?? '—';
                              return DataCell(
                                Center(
                                  child: Text(
                                    score,
                                    style: TextStyle(
                                      fontWeight:
                                          score == '—'
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                      color:
                                          score == '—'
                                              ? AppColors.textSecondary
                                              : AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color textColor,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
