import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_url_helper.dart';

class StudentPhotoCapturePanel extends StatelessWidget {
  const StudentPhotoCapturePanel({
    super.key,
    required this.selectedStudent,
    required this.pickedImage,
    required this.isUploading,
    required this.onBackPressed,
    required this.onCapturePhoto,
    required this.onUploadAndAssignPhoto,
    required this.onDiscardPickedImage,
  });

  final Map<String, dynamic> selectedStudent;
  final File? pickedImage;
  final bool isUploading;

  final VoidCallback onBackPressed;
  final ValueChanged<ImageSource> onCapturePhoto;
  final VoidCallback onUploadAndAssignPhoto;
  final VoidCallback onDiscardPickedImage;

  @override
  Widget build(BuildContext context) {
    final name = selectedStudent['name'] ?? 'No Name';
    final rollNo = selectedStudent['roll_no'] ?? 'No Roll No';
    final currentImgUrl = selectedStudent['image_url'] as String?;
    final hasCurrentImg = currentImgUrl != null && currentImgUrl.isNotEmpty;

    final className = selectedStudent['class']?['name']?.toString() ?? 'Unknown Class';
    final sectionName = selectedStudent['section']?['name']?.toString() ?? 'Unknown Section';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginPage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
    

          // Student Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.primary.withValues(alpha: 0.01),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headerSmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Roll: $rollNo',
                        style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$className - $sectionName',
                      style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),

          // Image Preview Container
          Center(
            child: Column(
              children: [
                if (pickedImage != null) ...[
                  // Preview of picked photo
                  Text(
                    'NEW CAPTURED PHOTO',
                    style: AppTextStyles.labelXsUppercase.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.primary, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                      image: DecorationImage(
                        image: FileImage(pickedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ] else ...[
                  // Current photo
                  Text(
                    hasCurrentImg ? 'CURRENT PROFILE PHOTO' : 'NO PROFILE PHOTO ASSIGNED',
                    style: AppTextStyles.labelXsUppercase,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: AppColors.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      image: hasCurrentImg
                          ? DecorationImage(
                              image: NetworkImage(ImageUrlHelper.sanitizeUrl(currentImgUrl)!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasCurrentImg
                        ? Icon(
                            Icons.person_outline_rounded,
                            size: 80,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),

          // Actions
          if (isUploading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Uploading Image...'),
                ],
              ),
            )
          else ...[
            if (pickedImage == null) ...[
              // Camera and Gallery buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => onCapturePhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Capture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => onCapturePhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Confirm upload and Cancel buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onUploadAndAssignPhoto,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successText,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton.icon(
                        onPressed: () => onCapturePhoto(ImageSource.camera),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Recapture'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton.icon(
                        onPressed: onDiscardPickedImage,
                        icon: const Icon(Icons.close_rounded, color: AppColors.errorText),
                        label: const Text(
                          'Discard',
                          style: TextStyle(color: AppColors.errorText),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.errorText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ],
      ),
    );
  }
}
