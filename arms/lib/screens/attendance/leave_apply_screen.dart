import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _attachmentName;
  bool _isAttachmentPdf = false;

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
              _attachmentName = 'Attached Image';
              _isAttachmentPdf = _attachmentPath!.toLowerCase().endsWith('.pdf');
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

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        setState(() {
          _hasAttachment = true;
          _attachmentPath = file.path;
          _attachmentName = file.name;
          _isAttachmentPdf = file.extension?.toLowerCase() == 'pdf';
        });
        if (mounted) {
          ArmsSnackbar.showSuccess(context, 'File attached: ${file.name}');
        }
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Failed to select file: $e');
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
                          activeColor: AppColors.onPrimary,
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
                isAttachmentPdf: _isAttachmentPdf,
                onPickAttachment: _pickAttachment,
                onRemoveAttachment: () {
                  setState(() {
                    _hasAttachment = false;
                    _attachmentPath = null;
                    _attachmentName = null;
                    _isAttachmentPdf = false;
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
                                            final sanitize = (String value) {
                                              return value
                                                  .trim()
                                                  .toLowerCase()
                                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                                  .replaceAll(RegExp(r'^_+|_+$'), '');
                                            };

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

                                          if (mounted) {
                                            ArmsSnackbar.showSuccess(context, _editingLeave != null ? 'Leave updated successfully' : 'Leave applied successfully');
                                            Navigator.pop(context, true);
                                          }
                                        } catch (e) {
                                          if (mounted) {
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

                                            if (mounted) {
                                              ArmsSnackbar.showSuccess(context, 'Leave application deleted successfully');
                                              Navigator.pop(context, true);
                                            }
                                          } catch (e) {
                                            if (mounted) {
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/leave-history');
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
