import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/excel_marks_parser.dart';
import 'widgets/excel_upload_card.dart';
import 'excel_preview_screen.dart';
import '../../widgets/arms_button.dart';
import '../../widgets/arms_dropdown_button.dart';

/// Screen for uploading Excel marks and configuring column mapping.
class ExcelMarksUploadScreen extends StatefulWidget {
  final Map<String, dynamic> exam;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> schoolsLookup;
  final List<Map<String, dynamic>> classesLookup;
  final List<Map<String, dynamic>> sectionsLookup;

  const ExcelMarksUploadScreen({
    super.key,
    required this.exam,
    required this.subjects,
    required this.students,
    required this.schoolsLookup,
    required this.classesLookup,
    required this.sectionsLookup,
  });

  @override
  State<ExcelMarksUploadScreen> createState() => _ExcelMarksUploadScreenState();
}

class _ExcelMarksUploadScreenState extends State<ExcelMarksUploadScreen> {
  // Mapping state
  final Map<String, String> _columnMapping = {
    'K': '',
    'L': '',
    'M': '',
    'N': '',
  };

  // File selection state
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  bool _isParsing = false;

  @override
  void initState() {
    super.initState();
    _autoMapColumns();
  }

  Map<String, dynamic>? _findSubjectByName(String keyword) {
    final kw = keyword.toLowerCase();
    for (final s in widget.subjects) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      if (name.contains(kw)) return s;
    }
    return null;
  }

  void _autoMapColumns() {
    final seriesName = widget.exam['series']?['name']?.toString() ?? '';
    final isNeet = seriesName.toUpperCase().contains('NEET');
    final isJee = seriesName.toUpperCase().contains('JEE');

    final phy = _findSubjectByName('physics') ??
        (widget.subjects.isNotEmpty ? widget.subjects[0] : null);
    final chem = _findSubjectByName('chemistry') ??
        (widget.subjects.length > 1 ? widget.subjects[1] : null);
    final bio = _findSubjectByName('biology') ??
        _findSubjectByName('botany') ??
        _findSubjectByName('zoology');
    final math = _findSubjectByName('math') ??
        _findSubjectByName('mathematics') ??
        (widget.subjects.length > 2 ? widget.subjects[2] : null);

    setState(() {
      if (isNeet) {
        _columnMapping['K'] = phy?['id'] ?? '';
        _columnMapping['L'] = chem?['id'] ?? '';
        _columnMapping['M'] = bio?['id'] ?? '';
        _columnMapping['N'] = bio?['id'] ?? '';
      } else if (isJee) {
        _columnMapping['K'] = phy?['id'] ?? '';
        _columnMapping['L'] = chem?['id'] ?? '';
        _columnMapping['M'] = math?['id'] ?? '';
        _columnMapping['N'] = '';
      } else {
        if (widget.subjects.isNotEmpty) {
          _columnMapping['K'] = widget.subjects[0]['id'] ?? '';
        }
        _columnMapping['L'] = '';
        _columnMapping['M'] = '';
        _columnMapping['N'] = '';
      }
    });
  }

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
        fileBytes = File(fileRef.path!).readAsBytesSync();
      }

      if (fileBytes == null) {
        throw Exception('Could not read file data. Please try again.');
      }

      setState(() {
        _selectedFileName = fileRef.name;
        _selectedFileBytes = fileBytes;
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

  void _parseExcelMarks() {
    if (_selectedFileBytes == null) return;

    setState(() => _isParsing = true);
    final messenger = ScaffoldMessenger.of(context);

    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        final preview = ExcelMarksParser.parseExcelMarks(
          fileBytes: _selectedFileBytes!,
          columnMapping: _columnMapping,
          exam: widget.exam,
          subjects: widget.subjects,
          students: widget.students,
        );

        if (!mounted) return;

        setState(() {
          _isParsing = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('Excel parsing completed successfully. Matched ${preview['derivedRows']} students!'),
            backgroundColor: AppColors.successText,
          ),
        );

        // Open the preview screen instead of showing it inside a popup
        final result = await Navigator.push<Map<String, Map<String, String>>>(
          context,
          MaterialPageRoute(
            builder: (context) => ExcelPreviewScreen(
              excelPreview: preview,
              subjects: widget.subjects,
            ),
          ),
        );

        if (result != null && mounted) {
          Navigator.pop(context, result);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isParsing = false);
          _showErrorDialog(e.toString().replaceAll('Exception:', '').trim());
        }
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.errorText, size: 28),
            const SizedBox(width: 12),
            Text('Validation Error', style: AppTextStyles.headerSmall.copyWith(color: AppColors.errorText)),
          ],
        ),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLargeScreen = media.size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Import Marks from Excel',
          style: AppTextStyles.headerSmall.copyWith(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.outlineLight,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select file and configure column mapping.',
                      style: AppTextStyles.labelXs,
                    ),
                    const SizedBox(height: 16),
                    _buildUploadAndMappingStep(),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 24.0 : 16.0,
                vertical: 16.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: AppColors.outlineLight,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ArmsButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: ArmsButtonVariant.secondary,
                    size: isLargeScreen ? ArmsButtonSize.large : ArmsButtonSize.medium,
                  ),
                  const SizedBox(width: 12),
                  ArmsButton(
                    label: 'Parse & Preview',
                    onPressed: _selectedFileBytes == null ? null : _parseExcelMarks,
                    isLoading: _isParsing,
                    variant: ArmsButtonVariant.primary,
                    size: isLargeScreen ? ArmsButtonSize.large : ArmsButtonSize.medium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadAndMappingStep() {
    final isLarge = MediaQuery.of(context).size.width > 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcelUploadCard(selectedFileName: _selectedFileName, onPickFile: _pickExcelFile),
        const SizedBox(height: 24),
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
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (isLarge) ...[
                Row(
                  children: [
                    Expanded(child: _buildColumnDropdown('K', 'Physics/Marks')),
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
                style: AppTextStyles.labelXs.copyWith(fontSize: isLarge ? 12 : 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnDropdown(String columnLetter, String helperLabel) {
    final mappedSubjectId = _columnMapping[columnLetter] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Column $columnLetter ($helperLabel)',
          style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ArmsDropdownButton<String>(
          value: widget.subjects.any((s) => s['id'] == mappedSubjectId) ? mappedSubjectId : '',
          isExpanded: true,
          onChanged: (newValue) => setState(() => _columnMapping[columnLetter] = newValue ?? ''),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('Disabled / Ignore Column', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            ...widget.subjects.map((sub) {
              return DropdownMenuItem<String>(
                value: sub['id'] as String,
                child: Text(sub['name'] as String? ?? 'Subject', style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
              );
            }),
          ],
        ),
      ],
    );
  }
}
