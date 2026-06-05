import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

void showDownloadResultsSheet({
  required BuildContext context,
  required String initialSelection,
  required String initialFormat,
  required Function(String selection, String format) onConfirm,
}) {
  String selection = initialSelection;
  String format = initialFormat;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          Widget buildSelectionRadio(String val) {
            final isSelected = selection == val;
            return GestureDetector(
              onTap: () {
                setModalState(() => selection = val);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.cardSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outlineMediumLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      val,
                      style: AppTextStyles.labelXs.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    Radio<String>(
                      value: val,
                      groupValue: selection,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => selection = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          Widget buildFormatButton(String fmt, IconData icon, Color iconColor) {
            final isSelected = format == fmt;
            return GestureDetector(
              onTap: () {
                setModalState(() => format = fmt);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 36, color: iconColor),
                    const SizedBox(height: 8),
                    Text(
                      fmt,
                      style: AppTextStyles.labelXs.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.outlineMediumLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Download Results',
                          style: AppTextStyles.headerSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('SELECTION', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 8),
                    buildSelectionRadio('All students'),
                    buildSelectionRadio('Attempted students'),
                    buildSelectionRadio('Not attempted students'),
                    const SizedBox(height: 16),
                    Text('EXPORT FORMAT', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildFormatButton(
                            'PDF Format',
                            Icons.picture_as_pdf,
                            AppColors.errorText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildFormatButton(
                            'Excel Sheet',
                            Icons.table_chart,
                            AppColors.successText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onConfirm(selection, format);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        child: Text(
                          'Confirm Download',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
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
