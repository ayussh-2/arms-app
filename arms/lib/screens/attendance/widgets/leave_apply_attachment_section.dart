import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/image_url_helper.dart';

class LeaveApplyAttachmentSection extends StatelessWidget {
  final bool hasAttachment;
  final String? attachmentPath;
  final String? previewImagePath;
  final bool isAttachmentPdf;
  final bool isProcessing;
  final VoidCallback onPickAttachment;
  final VoidCallback onRemoveAttachment;
  final VoidCallback? onTapAttachment;

  const LeaveApplyAttachmentSection({
    super.key,
    required this.hasAttachment,
    required this.attachmentPath,
    this.previewImagePath,
    required this.isAttachmentPdf,
    required this.isProcessing,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    this.onTapAttachment,
  });

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (hasAttachment) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTapAttachment,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: previewImagePath != null
                    ? Image.file(
                        File(previewImagePath!),
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                      )
                    : (isAttachmentPdf
                        ? const Center(
                            child: Icon(Icons.picture_as_pdf, color: AppColors.errorText, size: 36),
                          )
                        : (attachmentPath != null
                            ? (attachmentPath!.startsWith('http')
                                ? (ImageUrlHelper.sanitizeUrl(attachmentPath!) != null
                                    ? Image.network(
                                        ImageUrlHelper.sanitizeUrl(attachmentPath!)!,
                                        fit: BoxFit.cover,
                                        width: 80,
                                        height: 80,
                                      )
                                    : const Center(
                                        child: Icon(Icons.file_present, color: AppColors.primary),
                                      ))
                                : Image.file(
                                    File(attachmentPath!),
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                  ))
                            : const Center(
                                child: Icon(Icons.file_present, color: AppColors.primary),
                              ))),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemoveAttachment,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.delete, color: AppColors.errorText, size: 14),
              ),
            ),
          ),
        ],
      );
    }

    // Default state: show pick attachment (plus button)
    return GestureDetector(
      onTap: onPickAttachment,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
          border: Border.all(
            color: AppColors.outlineLight,
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
        ),
      ),
    );
  }
}
