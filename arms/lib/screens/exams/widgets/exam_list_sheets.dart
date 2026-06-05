import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/exam_html_generator.dart';
import '../../../core/services/exam_pdf_generator.dart';
import 'exam_list_helpers.dart';

void showFilterOptions({
  required BuildContext context,
  required String label,
  required String? currentValue,
  required List<String> options,
  required ValueChanged<String?> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.outlineMediumLight, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter by $label', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return RadioListTile<String?>(
                        title: Text('All ${label.toLowerCase()}', style: AppTextStyles.bodyMedium),
                        value: null,
                        groupValue: currentValue,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          onSelected(val);
                          Navigator.pop(ctx);
                        },
                      );
                    }
                    final option = options[index - 1];
                    return RadioListTile<String?>(
                      title: Text(option, style: AppTextStyles.bodyMedium),
                      value: option,
                      groupValue: currentValue,
                      onChanged: (val) {
                        onSelected(val);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showDownloadReportDrawer({
  required BuildContext context,
  required Map<String, dynamic> exam,
}) {
  var prefs = ExamReportPreferences(
    isMultiExam: false,
    includeStudentPic: false,
    showMaxMarks: true,
    showGrandTotal: true,
    showOverallPercentage: true,
    showOverallRank: true,
    orientation: 'portrait',
  );
  bool isGenerating = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(color: AppColors.outlineMediumLight, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Report Export Settings', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                        IconButton(icon: const Icon(Icons.close), onPressed: isGenerating ? null : () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('COLUMNS & DISPLAY CONFIG', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 8),
                    _buildDrawerToggleRow(setModalState, 'Include Student Picture', prefs.includeStudentPic, (v) => prefs = prefs.copyWith(includeStudentPic: v), isGenerating),
                    _buildDrawerToggleRow(setModalState, 'Show Max Marks', prefs.showMaxMarks, (v) => prefs = prefs.copyWith(showMaxMarks: v), isGenerating),
                    _buildDrawerToggleRow(setModalState, 'Grand Total', prefs.showGrandTotal, (v) => prefs = prefs.copyWith(showGrandTotal: v), isGenerating),
                    _buildDrawerToggleRow(setModalState, 'Overall Percentage', prefs.showOverallPercentage, (v) => prefs = prefs.copyWith(showOverallPercentage: v), isGenerating),
                    _buildDrawerToggleRow(setModalState, 'Overall Rank', prefs.showOverallRank, (v) => prefs = prefs.copyWith(showOverallRank: v), isGenerating),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isGenerating
                            ? null
                            : () async {
                                setModalState(() => isGenerating = true);
                                await ExamPdfGenerator.handleGeneratePdf(
                                  context: context,
                                  exam: exam,
                                  prefs: prefs,
                                  bottomSheetContext: ctx,
                                );
                                if (ctx.mounted) {
                                  setModalState(() => isGenerating = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isGenerating
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Generate PDF', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildDrawerToggleRow(StateSetter setModalState, String title, bool val, ValueChanged<bool> onChanged, bool isGenerating) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.bodyMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
        Switch(
          value: val,
          activeThumbColor: AppColors.primary,
          onChanged: isGenerating
              ? null
              : (v) {
                  setModalState(() {
                    onChanged(v);
                  });
                },
        ),
      ],
    ),
  );
}

void showActionSheet({
  required BuildContext context,
  required Map<String, dynamic> exam,
  required VoidCallback onEditMarks,
  required VoidCallback onViewReport,
  required VoidCallback onDownloadPdf,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam['name'] ?? '', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${exam['series']?['name'] ?? ''}',
                      style: AppTextStyles.labelXs,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SheetButton(
                icon: Icons.edit,
                label: 'Edit Marks',
                color: AppColors.primary,
                filled: true,
                onTap: onEditMarks,
              ),
              const SizedBox(height: 8),
              SheetButton(
                icon: Icons.description_outlined,
                label: 'View Report',
                onTap: onViewReport,
              ),
              const SizedBox(height: 8),
              SheetButton(
                icon: Icons.download_outlined,
                label: 'Download PDF',
                onTap: onDownloadPdf,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
