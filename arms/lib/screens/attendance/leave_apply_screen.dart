import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/image_compress_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/components/arms_button.dart';
import '../../widgets/components/arms_textarea_field.dart';
import '../../widgets/arms_dropdown_selector.dart';
import '../../widgets/arms_picker_sheet.dart';
import '../../widgets/arms_snackbar.dart';
import '../../widgets/components/arms_confirm_dialog.dart';
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
  List<String> _attachmentPaths = [];
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
              if (imgUrl.trim().startsWith('[')) {
                try {
                  final parsed = jsonDecode(imgUrl) as List;
                  _attachmentPaths = parsed.map((e) => e.toString()).toList();
                } catch (_) {
                  _attachmentPaths = [imgUrl];
                }
              } else {
                _attachmentPaths = [imgUrl];
              }
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
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          final newPaths = <String>[];
          for (final file in pickedFiles) {
            final compressedFile = await ImageCompressUtils.compressImageUnderSize(File(file.path));
            newPaths.add(compressedFile.path);
          }
          setState(() {
            _attachmentPaths.addAll(newPaths);
          });
          if (mounted) {
            ArmsSnackbar.showSuccess(context, '${pickedFiles.length} photo(s) added.');
          }
        }
      } else {
        final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null) {
          final compressedFile = await ImageCompressUtils.compressImageUnderSize(File(pickedFile.path));
          setState(() {
            _attachmentPaths.add(compressedFile.path);
          });
          if (mounted) {
            ArmsSnackbar.showSuccess(context, 'Photo captured and added.');
          }
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
      appBar: ArmsTopAppBar(
        showBackButton: true,
        title: _editingLeave != null ? 'Edit Leave' : 'Apply Leave',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              ArmsDropdownSelector(
                label: 'FROM DATE',
                value: AppDateUtils.formatToDMY(_fromDate),
                icon: Icons.calendar_today_outlined,
                onTap: _pickFromDate,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              ArmsDropdownSelector(
                label: 'TO DATE',
                value: AppDateUtils.formatToDMY(_toDate),
                icon: Icons.calendar_today_outlined,
                onTap: _pickToDate,
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
              ArmsTextAreaField(
                controller: _reasonController,
                hintText: 'Enter details here...',
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a reason for the leave';
                  }
                  return null;
                },
                fillColor: AppColors.cardSurface,
                hasBorder: true,
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
                    ArmsTextAreaField(
                      controller: _rejectedReasonController,
                      hintText: 'If rejected, specify why...',
                      maxLines: 3,
                      onChanged: (val) {
                        if (val.trim().isNotEmpty && _isApproved) {
                          setState(() => _isApproved = false);
                        }
                      },
                      fillColor: AppColors.cardSurface,
                      hasBorder: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              LeaveApplyAttachmentSection(
                attachmentPaths: _attachmentPaths,
                isProcessing: _isProcessingAttachment,
                onPickAttachment: _showAttachmentSourceSelector,
                onRemoveAttachment: (index) {
                  setState(() {
                    _attachmentPaths.removeAt(index);
                  });
                },
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
                          ArmsButton(
                            label: _editingLeave != null ? 'Save' : 'Apply',
                            isLoading: isLoading,
                            variant: ArmsButtonVariant.primary,
                            size: ArmsButtonSize.large,
                            fullWidth: true,
                            onPressed: () async {
                                      if (_selectedStudent == null) {
                                        ArmsSnackbar.showError(context, 'Please search and select a student first');
                                        return;
                                      }
                                      if (_formKey.currentState!.validate()) {
                                        setState(() => _isSaving = true);
                                        try {
                                          String? leaveAttachmentUrl;

                                          if (_attachmentPaths.isNotEmpty) {
                                            final List<String> uploadedUrls = [];
                                            final orgFolder = AuthService.currentAdmin?.organization?.name ?? 'org';
                                            final rollNo = _selectedStudent?['roll_no']?.toString() ?? 'unknown';
                                            final schoolName = _selectedStudent?['school']?['name']?.toString() ?? 'school';
                                            final className = _selectedStudent?['class']?['name']?.toString() ?? 'class';
                                            final sectionName = _selectedStudent?['section']?['name']?.toString() ?? 'section';
                                            String sanitize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');

                                            for (int i = 0; i < _attachmentPaths.length; i++) {
                                              final path = _attachmentPaths[i];
                                              if (path.startsWith('http')) {
                                                uploadedUrls.add(path);
                                              } else {
                                                File fileToUpload = File(path);
                                                final timestamp = DateTime.now().millisecondsSinceEpoch;
                                                final filenameBase = [timestamp, i, sanitize(rollNo), sanitize(schoolName), sanitize(className), sanitize(sectionName)].join('-');

                                                final uploadedUrl = await UploadService.uploadFile(
                                                  apiUrlPath: '/api/leave-applications',
                                                  organisationFolder: orgFolder,
                                                  filenameBase: filenameBase,
                                                  file: fileToUpload,
                                                );
                                                uploadedUrls.add(uploadedUrl);
                                              }
                                            }

                                            if (uploadedUrls.length == 1) {
                                              leaveAttachmentUrl = uploadedUrls.first;
                                            } else if (uploadedUrls.length > 1) {
                                              leaveAttachmentUrl = jsonEncode(uploadedUrls);
                                            }
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
                          ),
              const SizedBox(height: 12),
                          if (_editingLeave != null) ...[
                            ArmsButton(
                              label: 'Delete Application',
                              onPressed: () async {
                                final confirm = await ArmsConfirmDialog.show(
                                  context,
                                  title: 'Delete Leave',
                                  message: 'Are you sure you want to delete this leave application? This action cannot be undone.',
                                  confirmLabel: 'Delete',
                                  cancelLabel: 'Cancel',
                                  isDestructive: true,
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
                              variant: ArmsButtonVariant.destructive,
                              size: ArmsButtonSize.large,
                              isLoading: isLoading,
                              fullWidth: true,
                            ),
                            const SizedBox(height: 12),
                          ],
                          ArmsButton(
                            label: 'Cancel',
                            onPressed: () => Navigator.pop(context),
                            variant: ArmsButtonVariant.text,
                            size: ArmsButtonSize.large,
                            fullWidth: true,
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
