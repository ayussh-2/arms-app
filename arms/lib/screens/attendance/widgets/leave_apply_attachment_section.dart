import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/image_url_helper.dart';

class LeaveApplyAttachmentSection extends StatelessWidget {
  final List<String> attachmentPaths;
  final bool isProcessing;
  final VoidCallback onPickAttachment;
  final Function(int index) onRemoveAttachment;

  const LeaveApplyAttachmentSection({
    super.key,
    required this.attachmentPaths,
    required this.isProcessing,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
  });

  void _showAttachmentPreview(BuildContext context, String path) {
    final isHttp = path.startsWith('http');
    final isPdf = path.toLowerCase().endsWith('.pdf');
    final displayUrl = isHttp ? ImageUrlHelper.sanitizeUrl(path) : null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Attachment Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.cardSurface,
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isPdf
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf, color: AppColors.errorText, size: 80),
                              SizedBox(height: 12),
                              Text('PDF Document', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          )
                        : InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: isHttp
                                ? (displayUrl != null
                                    ? Image.network(displayUrl, fit: BoxFit.contain)
                                    : const Center(child: Icon(Icons.broken_image, size: 60)))
                                : Image.file(File(path), fit: BoxFit.contain),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemoveAttachment(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorText),
            SizedBox(width: 8),
            Text('Remove Attachment', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this attachment?',
          style: TextStyle(color: AppColors.textMain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRemoveAttachment(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: onPickAttachment,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              '+ Add Photo',
              style: AppTextStyles.labelXs.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentThumbnail(BuildContext context, String path, int index) {
    final isHttp = path.startsWith('http');
    final isPdf = path.toLowerCase().endsWith('.pdf');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _showAttachmentPreview(context, path),
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
              child: isPdf
                  ? const Center(
                      child: Icon(Icons.picture_as_pdf, color: AppColors.errorText, size: 36),
                    )
                  : (isHttp
                      ? (ImageUrlHelper.sanitizeUrl(path) != null
                          ? Image.network(
                              ImageUrlHelper.sanitizeUrl(path)!,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            )
                          : const Center(
                              child: Icon(Icons.file_present, color: AppColors.primary),
                            ))
                      : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        )),
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => _confirmRemoveAttachment(context, index),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHMENTS (${attachmentPaths.length})',
          style: AppTextStyles.labelXsUppercase.copyWith(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < attachmentPaths.length; i++) ...[
                _buildAttachmentThumbnail(context, attachmentPaths[i], i),
                const SizedBox(width: 12),
              ],
              _buildAddPhotoButton(),
            ],
          ),
        ),
      ],
    );
  }
}
