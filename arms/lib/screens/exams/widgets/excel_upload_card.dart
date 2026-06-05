import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Widget displaying the file‑picker card used in the Excel upload modal.
/// It shows the selected file name and a button to pick a new file.
class ExcelUploadCard extends StatelessWidget {
  final String? selectedFileName;
  final VoidCallback onPickFile;

  const ExcelUploadCard({
    super.key,
    required this.selectedFileName,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Excel File', style: AppTextStyles.labelXsUppercase),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
            ),
            if (selectedFileName != null) ...[
              const SizedBox(height: 12),
              Text('Selected: $selectedFileName', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
            ],
          ],
        ),
      ),
    );
  }
}
