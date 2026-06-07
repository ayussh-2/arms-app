import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/image_url_helper.dart';

class LeaveApplyAttachmentSection extends StatelessWidget {
  final bool hasAttachment;
  final String? attachmentPath;
  final bool isAttachmentPdf;
  final VoidCallback onPickAttachment;
  final VoidCallback onRemoveAttachment;

  const LeaveApplyAttachmentSection({
    super.key,
    required this.hasAttachment,
    required this.attachmentPath,
    required this.isAttachmentPdf,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTACHMENT', style: AppTextStyles.labelXsUppercase),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
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
                  child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            if (hasAttachment)
              Stack(
                children: [
                  GestureDetector(
                    onTap: onPickAttachment,
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
                        child: isAttachmentPdf
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.picture_as_pdf, color: AppColors.errorText, size: 36),
                                    SizedBox(height: 4),
                                    Text(
                                      'PDF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.errorText,
                                      ),
                                    ),
                                  ],
                                ),
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
                                  )),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
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
              ),
          ],
        ),
      ],
    );
  }
}
