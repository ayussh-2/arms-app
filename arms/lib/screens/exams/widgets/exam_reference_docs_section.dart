import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/graphql/queries.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/services/upload_service.dart';
import '../../../widgets/arms_snackbar.dart';

class ExamReferenceDocsSection extends StatefulWidget {
  final Map<String, dynamic> exam;
  final Function(String type, String newUrl) onPdfUploaded;

  const ExamReferenceDocsSection({
    super.key,
    required this.exam,
    required this.onPdfUploaded,
  });

  @override
  State<ExamReferenceDocsSection> createState() => _ExamReferenceDocsSectionState();
}

class _ExamReferenceDocsSectionState extends State<ExamReferenceDocsSection> {
  static const int _maxExamPdfSizeBytes = 3 * 1024 * 1024;
  bool _isUploading = false;

  String _sanitizeFilename(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
  }

  Future<void> _updatePdf(String type) async {
    final isAttendance = type == 'attendance';
    final title = isAttendance ? 'Attendance PDF' : 'Question Paper PDF';
    final examId = widget.exam['id']?.toString();

    if (examId == null || examId.trim().isEmpty) {
      ArmsSnackbar.showError(context, 'Create or open an exam before uploading the PDF');
      return;
    }

    final organisationFolder = AuthService.currentAdmin?.organization?.name.trim();
    if (organisationFolder == null || organisationFolder.isEmpty) {
      ArmsSnackbar.showError(context, 'Organisation folder is missing. Please login again.');
      return;
    }

    FilePickerResult? pickerResult;
    try {
      pickerResult = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
    } catch (e) {
      if (!mounted) return;
      ArmsSnackbar.showError(context, 'Failed to open file picker: $e');
      return;
    }

    if (!mounted) return;
    if (pickerResult == null || pickerResult.files.single.path == null) {
      return;
    }

    final filePath = pickerResult.files.single.path!;
    if (!filePath.toLowerCase().endsWith('.pdf')) {
      ArmsSnackbar.showError(context, 'Only PDF uploads are accepted');
      return;
    }

    final file = File(filePath);
    final fileSize = await file.length();
    if (!mounted) return;
    if (fileSize >= _maxExamPdfSizeBytes) {
      ArmsSnackbar.showError(context, 'PDF must be less than 3 MB');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final examName = (widget.exam['name'] ?? 'exam').toString();
      final uploadedUrl = await UploadService.uploadFile(
        apiUrlPath: '/api/exam-pdfs',
        organisationFolder: organisationFolder,
        filenameBase: _sanitizeFilename(examName),
        file: file,
        formFieldName: 'pdf',
        extraFields: {
          'examId': examId,
          'examName': examName,
          'kind': isAttendance ? 'attendance' : 'question',
        },
      );

      if (!mounted) return;
      final client = GraphQLProvider.of(context).value;
      final mutationResult = await client.mutate(MutationOptions(
        document: gql(GqlQueries.updateExamPdfs),
        variables: {
          'examId': examId,
          'attendancePdf': isAttendance ? uploadedUrl : widget.exam['attendance_pdf_url'],
          'questionPdf': !isAttendance ? uploadedUrl : widget.exam['question_pdf_url'],
        },
      ));

      if (mutationResult.hasException) throw mutationResult.exception!;

      widget.onPdfUploaded(type, uploadedUrl);

      if (mounted) {
        ArmsSnackbar.showSuccess(context, '$title uploaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Error updating PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildDocCardDynamic(String title, String? url, String type) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;
    String filename = '${title.replaceAll(" ", "_")}.pdf';
    if (hasUrl) {
      try {
        final uri = Uri.parse(url.trim());
        final lastSeg = uri.pathSegments.last;
        if (lastSeg.isNotEmpty && lastSeg.contains('.')) {
          filename = lastSeg;
        }
      } catch (_) {}
    }

    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUrl ? AppColors.outlineLight : AppColors.outlineMediumLight,
        ),
      ),
      child: hasUrl
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.errorText, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            filename,
                            style: AppTextStyles.labelXs.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton(
                          onPressed: _isUploading ? null : () => _updatePdf(type),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.outlineMediumLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                )
                              : Text(
                                  'Replace',
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: AppColors.textMain,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final uri = Uri.parse(url.trim());
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Could not open URL: $e'),
                                  backgroundColor: AppColors.errorText,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryFaint,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'View',
                            style: AppTextStyles.labelXs.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : InkWell(
              onTap: _isUploading ? null : () => _updatePdf(type),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    _isUploading ? 'Uploading...' : 'Upload New $title',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reference Documents'.toUpperCase(),
          style: AppTextStyles.labelXsUppercase.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildDocCardDynamic(
                'Attendance PDF',
                widget.exam['attendance_pdf_url'],
                'attendance',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocCardDynamic(
                'Question Paper',
                widget.exam['question_pdf_url'],
                'question',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
