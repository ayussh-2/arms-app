import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import '../../core/utils/image_url_helper.dart';
import '../../core/utils/image_compress_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_dropdown_selector.dart';
import '../../widgets/arms_picker_sheet.dart';
import '../../widgets/arms_snackbar.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/upload_service.dart';
import 'widgets/student_search_section.dart';
import 'widgets/leave_apply_attachment_section.dart';

class LeaveApplyScreen extends StatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  State<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends State<LeaveApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _rejectedReasonController = TextEditingController();

  Map<String, dynamic>? _selectedStudent;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 2));
  String _leaveType = 'FEVER';
  bool _isApproved = true;
  bool _isSaving = false;
  bool _hasAttachment = false;
  String? _attachmentPath;
  String? _previewImagePath;
  bool _isAttachmentPdf = false;
  bool _isProcessingAttachment = false;

  static const Map<String, String> leaveTypeMap = {
    'FEVER': 'fever',
    'MEDICAL SELF': 'medical_self',
    'MEDICAL RELATIVE': 'medical_relative',
    'MARRIAGE': 'marriage',
    'CASUAL': 'casual',
    'STOMACH PAIN': 'stomach_pain',
    'BODY PAIN HEADACHE': 'body_pain_headache',
    'OTHER': 'other',
  };

  final List<String> _leaveTypes = [
    'FEVER',
    'MEDICAL SELF',
    'MEDICAL RELATIVE',
    'MARRIAGE',
    'CASUAL',
    'STOMACH PAIN',
    'BODY PAIN HEADACHE',
    'OTHER',
  ];

  String _getUiLeaveType(String dbValue) {
    final cleanDbVal = dbValue.trim().toLowerCase();
    for (final entry in leaveTypeMap.entries) {
      if (entry.value == cleanDbVal) {
        return entry.key;
      }
    }
    final upper = cleanDbVal.toUpperCase().replaceAll('_', ' ');
    if (_leaveTypes.contains(upper)) {
      return upper;
    }
    return 'OTHER';
  }

  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isSearching = false;
  bool _hasLoadedArgs = false;
  Map<String, dynamic>? _editingLeave;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedArgs) {
      _hasLoadedArgs = true;
      try {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map) {
          final leave = args['leave'] != null ? Map<String, dynamic>.from(args['leave'] as Map) : null;
          final student = args['student'] != null ? Map<String, dynamic>.from(args['student'] as Map) : null;
          if (leave != null) {
            _editingLeave = leave;
            _selectedStudent = student;

            if (leave['from_date'] != null) {
              try {
                _fromDate = DateTime.parse(leave['from_date']);
              } catch (_) {}
            }
            if (leave['to_date'] != null) {
              try {
                _toDate = DateTime.parse(leave['to_date']);
              } catch (_) {}
            }

            _leaveType = _getUiLeaveType(leave['leave_type'] as String? ?? '');
            _reasonController.text = leave['reason'] ?? '';
            _isApproved = leave['approved'] as bool? ?? false;
            _rejectedReasonController.text = leave['rejected_reason'] ?? '';

            final imgUrl = leave['leave_application_image_url'] as String?;
            if (imgUrl != null && imgUrl.isNotEmpty) {
              _hasAttachment = true;
              _attachmentPath = imgUrl;
              _isAttachmentPdf = _checkIfPdf(imgUrl);
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing arguments in LeaveApplyScreen: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    _rejectedReasonController.dispose();
    _filteredStudents.clear();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  Future<void> _showAttachmentSourceSelector() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Attach Photo', style: AppTextStyles.headerSmall),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildSourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineLight),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.labelXs.copyWith(color: AppColors.textMain)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isProcessingAttachment = true;
    });
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        // Process the image: compress if exceeds 500KB
        final File compressedFile = await ImageCompressUtils.compressImageUnderSize(file);
        
        setState(() {
          _hasAttachment = true;
          _attachmentPath = compressedFile.path;
          _previewImagePath = compressedFile.path; // Show the compressed image itself in the preview
          _isAttachmentPdf = false;
        });
        
        if (mounted) {
          ArmsSnackbar.showSuccess(context, 'Photo processed and compressed.');
        }
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Failed to process photo: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAttachment = false;
        });
      }
    }
  }

  bool _checkIfPdf(String path) {
    try {
      final uri = Uri.parse(path);
      return uri.path.toLowerCase().endsWith('.pdf');
    } catch (_) {
      return path.toLowerCase().contains('.pdf');
    }
  }

  Future<void> _openAttachment() async {
    if (_attachmentPath == null) return;
    
    final isPdf = _isAttachmentPdf;
    final path = _attachmentPath!;
    
    if (isPdf) {
      try {
        if (path.startsWith('http')) {
          final uri = Uri.parse(path);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          final file = File(path);
          final exists = await file.exists();
          if (!mounted) return;
          if (exists) {
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => file.readAsBytes(),
              name: 'Leave Attachment',
            );
          } else {
            ArmsSnackbar.showError(context, 'PDF file not found locally.');
          }
        }
      } catch (e) {
        if (!mounted) return;
        ArmsSnackbar.showError(context, 'Could not open PDF: $e');
      }
    } else {
      // It's an image. Show full screen/zoomable image preview dialog!
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: path.startsWith('http')
                      ? Image.network(
                          ImageUrlHelper.sanitizeUrl(path) ?? path,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          File(path),
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemoveAttachment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
          side: const BorderSide(color: AppColors.outlineLight),
        ),
        title: Text(
          'Remove Attachment', 
          style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)
        ),
        content: Text(
          'Are you sure you want to remove this attachment?', 
          style: AppTextStyles.bodyMedium
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel', 
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.roundEight)
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _hasAttachment = false;
        _attachmentPath = null;
        _previewImagePath = null;
        _isAttachmentPdf = false;
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredStudents = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) return;

      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getPaginatedStudents),
          variables: {
            'organisationId': orgId,
            'searchQuery': query.trim(),
            'page': 1,
            'limit': 15,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (!mounted) return;
      if (result.data != null) {
        final studentsData = result.data!['getPaginatedStudents']?['students'] as List? ?? [];
        setState(() {
          _filteredStudents = studentsData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        });
      }
    } catch (e) {
      // Error is caught silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editingLeave != null ? 'Edit Leave' : 'Apply Leave', style: AppTextStyles.displayMobile),
              const SizedBox(height: AppSpacing.stackLg),
              StudentSearchSection(
                selectedStudent: _selectedStudent,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                filteredStudents: _filteredStudents,
                isSearching: _isSearching,
                onStudentSelected: (s) {
                  setState(() {
                    _selectedStudent = s;
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
                onStudentCleared: () {
                  setState(() {
                    _selectedStudent = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FROM DATE', style: AppTextStyles.labelXsUppercase),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickFromDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                              border: Border.all(color: AppColors.outlineLight),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppDateUtils.formatToDMY(_fromDate), style: AppTextStyles.bodyMedium),
                                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TO DATE', style: AppTextStyles.labelXsUppercase),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickToDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                              border: Border.all(color: AppColors.outlineLight),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppDateUtils.formatToDMY(_toDate), style: AppTextStyles.bodyMedium),
                                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),
              ArmsDropdownSelector(
                label: 'LEAVE TYPE',
                value: _leaveType,
                onTap: () => ArmsPickerSheet.show<String>(
                  context: context,
                  title: 'Select Leave Type',
                  items: _leaveTypes,
                  itemLabel: (val) => val,
                  selectedItem: _leaveType,
                  onItemSelected: (val) {
                    setState(() => _leaveType = val);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text('REASON', style: AppTextStyles.labelXsUppercase),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                style: AppTextStyles.bodyMedium,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a reason for the leave';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Enter details here...',
                  hintStyle: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                  fillColor: AppColors.cardSurface,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                    borderSide: const BorderSide(color: AppColors.outlineLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                    borderSide: const BorderSide(color: AppColors.outlineLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                  border: Border.all(color: AppColors.outlineLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Approved', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        Switch(
                          value: _isApproved,
                          activeThumbColor: AppColors.onPrimary,
                          activeTrackColor: AppColors.primary,
                          inactiveThumbColor: AppColors.outlineMedium,
                          inactiveTrackColor: AppColors.surfaceVariant,
                          onChanged: (val) {
                            setState(() {
                              _isApproved = val;
                              if (val) {
                                _rejectedReasonController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rejected Reason (forces Approved to OFF)',
                      style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _rejectedReasonController,
                      onChanged: (val) {
                        if (val.trim().isNotEmpty && _isApproved) {
                          setState(() => _isApproved = false);
                        }
                      },
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'If rejected, specify why...',
                        hintStyle: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                        fillColor: AppColors.background,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.roundEight),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              LeaveApplyAttachmentSection(
                hasAttachment: _hasAttachment,
                attachmentPath: _attachmentPath,
                previewImagePath: _previewImagePath,
                isAttachmentPdf: _isAttachmentPdf,
                isProcessing: _isProcessingAttachment,
                onPickAttachment: _showAttachmentSourceSelector,
                onRemoveAttachment: _confirmRemoveAttachment,
                onTapAttachment: _openAttachment,
              ),
              const SizedBox(height: AppSpacing.stackLg),
              Mutation(
                options: MutationOptions(
                  document: gql(GqlQueries.deleteLeave),
                ),
                builder: (RunMutation runDelete, QueryResult? deleteResult) {
                  return Mutation(
                    options: MutationOptions(
                      document: gql(GqlQueries.createLeave),
                    ),
                    builder: (RunMutation runCreate, QueryResult? createResult) {
                      final isLoading = _isSaving || 
                          (createResult?.isLoading ?? false) || 
                          (deleteResult?.isLoading ?? false);

                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (_selectedStudent == null) {
                                        ArmsSnackbar.showError(context, 'Please search and select a student first');
                                        return;
                                      }
                                      if (_formKey.currentState!.validate()) {
                                        setState(() => _isSaving = true);
                                        try {
                                          String? leaveAttachmentUrl = _attachmentPath;
                                          
                                          if (_hasAttachment && _attachmentPath != null && !_attachmentPath!.startsWith('http')) {
                                            final rollNo = _selectedStudent?['roll_no']?.toString() ?? 'unknown';
                                            final schoolName = _selectedStudent?['school']?['name']?.toString() ?? 'school';
                                            final className = _selectedStudent?['class']?['name']?.toString() ?? 'class';
                                            final sectionName = _selectedStudent?['section']?['name']?.toString() ?? 'section';
                                            
                                            final timestamp = DateTime.now().millisecondsSinceEpoch;
                                            String sanitize(String value) {
                                              return value
                                                  .trim()
                                                  .toLowerCase()
                                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                                  .replaceAll(RegExp(r'^_+|_+$'), '');
                                            }

                                            final filenameBase = [
                                              timestamp,
                                              sanitize(rollNo),
                                              sanitize(schoolName),
                                              sanitize(className),
                                              sanitize(sectionName),
                                            ].join('-');
                                            
                                            final orgFolder = AuthService.currentAdmin?.organization?.name ?? 'org';
                                            
                                            final uploadedUrl = await UploadService.uploadFile(
                                              apiUrlPath: '/api/leave-applications',
                                              organisationFolder: orgFolder,
                                              filenameBase: filenameBase,
                                              file: File(_attachmentPath!),
                                            );
                                            
                                            leaveAttachmentUrl = uploadedUrl;
                                          }

                                          final createRes = await runCreate({
                                            'input': {
                                              if (_editingLeave != null) 'id': _editingLeave!['id'],
                                              'organisation_id': AuthService.currentAdmin?.organization?.id,
                                              'student_id': _selectedStudent?['id'],
                                              'from_date': AppDateUtils.formatToYMD(_fromDate),
                                              'to_date': AppDateUtils.formatToYMD(_toDate),
                                              'leave_type': leaveTypeMap[_leaveType] ?? 'other',
                                              'reason': _reasonController.text.trim(),
                                              'approved': _isApproved,
                                              'approved_by': AuthService.currentAdmin?.id,
                                              'leave_application_image_url': leaveAttachmentUrl,
                                              'rejected_reason': !_isApproved && _rejectedReasonController.text.trim().isNotEmpty
                                                  ? _rejectedReasonController.text.trim()
                                                  : null,
                                            }
                                          }).networkResult;

                                          if (createRes?.hasException == true) {
                                            throw createRes!.exception!;
                                          }

                                          if (context.mounted) {
                                            ArmsSnackbar.showSuccess(context, _editingLeave != null ? 'Leave updated successfully' : 'Leave applied successfully');
                                            Navigator.pop(context, true);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ArmsSnackbar.showError(context, 'Error: $e');
                                          }
                                        } finally {
                                          if (mounted) setState(() => _isSaving = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(color: AppColors.onPrimary)
                                  : Text(_editingLeave != null ? 'Save' : 'Apply', style: AppTextStyles.headerSmall.copyWith(color: AppColors.onPrimary)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_editingLeave != null) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppColors.background,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                                              side: const BorderSide(color: AppColors.outlineLight),
                                            ),
                                            title: Text('Delete Leave', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                                            content: Text('Are you sure you want to delete this leave application? This action cannot be undone.', style: AppTextStyles.bodyMedium),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.errorText,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundEight)),
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          setState(() => _isSaving = true);
                                          try {
                                            final orgId = AuthService.currentAdmin?.organization?.id;
                                            final res = await runDelete({
                                              'id': _editingLeave!['id'],
                                              'organisationId': orgId,
                                            }).networkResult;

                                            if (res?.hasException == true) {
                                              throw res!.exception!;
                                            }

                                            if (context.mounted) {
                                              ArmsSnackbar.showSuccess(context, 'Leave application deleted successfully');
                                              Navigator.pop(context, true);
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ArmsSnackbar.showError(context, 'Error deleting: $e');
                                            }
                                          } finally {
                                            if (mounted) setState(() => _isSaving = false);
                                          }
                                        }
                                      },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.errorText, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
                                ),
                                child: Text('Delete Application', style: AppTextStyles.headerSmall.copyWith(color: AppColors.errorText)),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.onSurfaceVariant,
                              ),
                              child: Text('Cancel', style: AppTextStyles.headerSmall.copyWith(color: AppColors.onSurfaceVariant)),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedStudent == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/leave-history',
                    arguments: {
                      'student': _selectedStudent,
                    },
                  );
                },
                backgroundColor: AppColors.cardSurface,
                foregroundColor: AppColors.onSurfaceVariant,
                elevation: 2,
                shape: const CircleBorder(),
                child: const Icon(Icons.history),
              ),
            ),
    );
  }
}
