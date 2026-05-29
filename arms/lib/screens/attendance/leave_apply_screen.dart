import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_dropdown_selector.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/utils/image_url_helper.dart';

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
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final leave = args['leave'] as Map<String, dynamic>?;
        final student = args['student'] as Map<String, dynamic>?;
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
          
          if (leave['leave_application_image_url'] != null && (leave['leave_application_image_url'] as String).isNotEmpty) {
            _hasAttachment = true;
            _attachmentPath = leave['leave_application_image_url'];
            _attachmentName = 'Attached Image';
            _isAttachmentPdf = _attachmentPath!.toLowerCase().endsWith('.pdf');
          }
        }
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

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatNiceDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File attached: ${file.name}'),
              backgroundColor: AppColors.successText,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select file: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
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
          _filteredStudents = studentsData.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error searching students: $e');
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

                  // Student Picker / Search
                  if (_selectedStudent == null) ...[
                    Text('STUDENT', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(AppRadius.roundFull),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: AppTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                          hintText: 'Search Student...',
                          hintStyle: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    if (_isSearching && _filteredStudents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                          border: Border.all(color: AppColors.outlineMediumLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredStudents.length,
                          itemBuilder: (ctx, idx) {
                            final s = _filteredStudents[idx];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.surfaceVariant,
                                backgroundImage: s['image_url'] != null ? NetworkImage(ImageUrlHelper.sanitizeUrl(s['image_url'])!) : null,
                                child: s['image_url'] == null ? Text(s['name']?[0] ?? 'S') : null,
                              ),
                              title: Text(s['name'] ?? '', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                              subtitle: Text('Roll No: ${s['roll_no'] ?? ''}', style: AppTextStyles.labelXs),
                              onTap: () {
                                setState(() {
                                  _selectedStudent = s;
                                  _isSearching = false;
                                  _searchController.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ] else if (_isSearching && _filteredStudents.isEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('No students found', style: AppTextStyles.labelXs),
                      ),
                    ],
                  ] else ...[
                    // Selected Student Card
                    Text('SELECTED STUDENT', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                        border: Border.all(color: AppColors.outlineLight),
                      ),
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final studentImg = _selectedStudent!['image_url'] as String?;
                              final hasImg = studentImg != null && studentImg.trim().isNotEmpty;
                              return CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surfaceVariant,
                                backgroundImage: hasImg
                                    ? NetworkImage(ImageUrlHelper.sanitizeUrl(studentImg)!)
                                    : null,
                                child: !hasImg
                                    ? Text(_selectedStudent!['name']?[0] ?? 'S')
                                    : null,
                              );
                            }
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedStudent!['name'] ?? '', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                Builder(
                                  builder: (context) {
                                    final rollNoVal = _selectedStudent!['roll_no']?.toString();
                                    final hasRollNo = rollNoVal != null && rollNoVal.trim().isNotEmpty && rollNoVal != 'null';
                                    final rollNoDisplay = hasRollNo ? 'Roll No: $rollNoVal' : 'Roll No: N/A';
                                    return Text(rollNoDisplay, style: AppTextStyles.labelXs);
                                  }
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.errorText),
                            onPressed: () {
                              setState(() {
                                _selectedStudent = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.stackMd),

                  // Date fields side-by-side
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
                                    Text(_formatNiceDate(_fromDate), style: AppTextStyles.bodyMedium),
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
                                    Text(_formatNiceDate(_toDate), style: AppTextStyles.bodyMedium),
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
                    onTap: () => _showSingleSelectSheet(
                      title: 'Select Leave Type',
                      currentValue: _leaveType,
                      options: _leaveTypes,
                      onSelected: (val) {
                        setState(() => _leaveType = val);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),

                  // Reason text field
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

                  // Approval Controls Card
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

                  // Attachment Section
                  Text('ATTACHMENT', style: AppTextStyles.labelXsUppercase),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Upload button
                      GestureDetector(
                        onTap: _pickAttachment,
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

                      // Image or PDF attachment preview if active
                      if (_hasAttachment)
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _pickAttachment,
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
                                  child: _isAttachmentPdf
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
                                      : (_attachmentPath != null
                                          ? (_attachmentPath!.startsWith('http')
                                              ? Image.network(
                                                  ImageUrlHelper.sanitizeUrl(_attachmentPath!)!,
                                                  fit: BoxFit.cover,
                                                  width: 80,
                                                  height: 80,
                                                )
                                              : Image.file(
                                                  File(_attachmentPath!),
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
                                onTap: () {
                                  setState(() {
                                    _hasAttachment = false;
                                    _attachmentPath = null;
                                    _attachmentName = null;
                                    _isAttachmentPdf = false;
                                  });
                                },
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
                  const SizedBox(height: AppSpacing.stackLg),

                  // Actions (Apply / Cancel)
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
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please search and select a student first'),
                                            backgroundColor: AppColors.errorText,
                                          ),
                                        );
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
                                              'student_id': _selectedStudent!['id'],
                                              'from_date': _formatDate(_fromDate),
                                              'to_date': _formatDate(_toDate),
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
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(_editingLeave != null ? 'Leave updated successfully' : 'Leave applied successfully'),
                                                backgroundColor: AppColors.successText,
                                              ),
                                            );
                                            Navigator.pop(context, true);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: AppColors.errorText,
                                              ),
                                            );
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
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Leave application deleted successfully'),
                                                  backgroundColor: AppColors.successText,
                                                ),
                                              );
                                              Navigator.pop(context, true);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error deleting: $e'),
                                                  backgroundColor: AppColors.errorText,
                                                ),
                                              );
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

  void _showSingleSelectSheet({
    required String title,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                Text(title, style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSelected = opt == currentValue;
                      return ListTile(
                        title: Text(
                          opt,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textMain,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                        onTap: () {
                          onSelected(opt);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
