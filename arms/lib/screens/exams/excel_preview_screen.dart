import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/excel_preview_panel.dart';
import '../../widgets/components/arms_button.dart';

/// Screen for reviewing imported marks preview and validation details.
/// Shows required vs derived stats, missing/extra students, and data table.
class ExcelPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> excelPreview;
  final List<Map<String, dynamic>> subjects;

  const ExcelPreviewScreen({
    super.key,
    required this.excelPreview,
    required this.subjects,
  });

  void _confirmExcelImport(BuildContext context) {
    final pendingMarks = excelPreview['pendingStudentMarks'] as Map<String, Map<String, String>>;
    Navigator.of(context).pop(pendingMarks);
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
          'Import Preview & Validation',
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
                      'Verify matching rows and parsed scores below before confirming.',
                      style: AppTextStyles.labelXs,
                    ),
                    const SizedBox(height: 16),
                    ExcelPreviewPanel(
                      excelPreview: excelPreview,
                      subjects: subjects,
                    ),
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
                    label: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: ArmsButtonVariant.secondary,
                    size: isLargeScreen ? ArmsButtonSize.large : ArmsButtonSize.medium,
                  ),
                  const SizedBox(width: 12),
                  ArmsButton(
                    label: 'Confirm Import',
                    onPressed: () => _confirmExcelImport(context),
                    variant: ArmsButtonVariant.primary,
                    backgroundColor: AppColors.successText,
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
}
