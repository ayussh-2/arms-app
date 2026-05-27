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
  String _leaveType = 'Fever';
  bool _isApproved = true;
  bool _isSaving = false;
  bool _hasAttachment = false;
  String? _attachmentPath;
  String? _attachmentName;
  bool _isAttachmentPdf = false;

  final List<String> _leaveTypes = ['Fever', 'Casual', 'Marriage', 'Other'];

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    _rejectedReasonController.dispose();
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

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredStudents = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name'] as String? ?? '').toLowerCase();
        final roll = s['roll_no']?.toString() ?? '';
        final q = query.toLowerCase();
        return name.contains(q) || roll.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        showBackButton: true,
      ),
      body: Query(
        options: QueryOptions(
          document: gql(GqlQueries.getStudents),
          variables: const {},
        ),
        builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
          if (result.data != null && _allStudents.isEmpty) {
            _allStudents = (result.data!['students'] as List? ?? []).cast<Map<String, dynamic>>();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackMd),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apply Leave', style: AppTextStyles.displayMobile),
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
                          border: Border.all(color: AppColors.outline.withOpacity(0.3)),
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
                                backgroundImage: s['image_url'] != null ? NetworkImage(s['image_url']) : null,
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
                        border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.surfaceVariant,
                            backgroundImage: _selectedStudent!['image_url'] != null
                                ? NetworkImage(_selectedStudent!['image_url'])
                                : null,
                            child: _selectedStudent!['image_url'] == null
                                ? Text(_selectedStudent!['name']?[0] ?? 'S')
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedStudent!['name'] ?? '', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                Text('CS-2023-${_selectedStudent!['roll_no']?.toString().padLeft(3, '0')}', style: AppTextStyles.labelXs),
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
                                  border: Border.all(color: AppColors.outline.withOpacity(0.15)),
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
                                  border: Border.all(color: AppColors.outline.withOpacity(0.15)),
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
                        borderSide: BorderSide(color: AppColors.outline.withOpacity(0.15)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                        borderSide: BorderSide(color: AppColors.outline.withOpacity(0.15)),
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
                      border: Border.all(color: AppColors.outline.withOpacity(0.15)),
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
                              color: AppColors.outline.withOpacity(0.15),
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
                                    border: Border.all(color: AppColors.outline.withOpacity(0.15)),
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
                                          ? Image.file(
                                              File(_attachmentPath!),
                                              fit: BoxFit.cover,
                                              width: 80,
                                              height: 80,
                                            )
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
                      document: gql(GqlQueries.applyLeave),
                    ),
                    builder: (RunMutation runApply, QueryResult? applyResult) {
                      return Mutation(
                        options: MutationOptions(
                          document: gql(GqlQueries.updateLeaveStatus),
                        ),
                        builder: (RunMutation runUpdate, QueryResult? updateResult) {
                          final isLoading = _isSaving || (applyResult?.isLoading ?? false) || (updateResult?.isLoading ?? false);

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
                                              // 1. Call applyLeave mutation
                                              final applyRes = await runApply({
                                                'input': {
                                                  'student_id': _selectedStudent!['id'],
                                                  'from_date': _formatDate(_fromDate),
                                                  'to_date': _formatDate(_toDate),
                                                  'leave_type': _leaveType.toLowerCase(),
                                                  'reason': _reasonController.text.trim(),
                                                  'admin_id': 'admin-001',
                                                }
                                              }).networkResult;

                                              if (applyRes?.hasException == true) {
                                                throw applyRes!.exception!;
                                              }

                                              final newLeave = applyRes?.data?['applyLeave'];
                                              if (newLeave != null && newLeave['id'] != null) {
                                                // 2. Call updateLeaveStatus if they marked approved status or provided rejected reason
                                                // If approved is true, or if they provided a rejection reason
                                                final leaveId = newLeave['id'];
                                                final rejectedReasonText = _rejectedReasonController.text.trim();
                                                
                                                final updateRes = await runUpdate({
                                                  'id': leaveId,
                                                  'approved': _isApproved,
                                                  'rejectedReason': rejectedReasonText.isNotEmpty ? rejectedReasonText : null,
                                                }).networkResult;

                                                if (updateRes?.hasException == true) {
                                                  throw updateRes!.exception!;
                                                }
                                              }

                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Leave applied successfully'),
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
                                      : Text('Apply', style: AppTextStyles.headerSmall.copyWith(color: AppColors.onPrimary)),
                                ),
                              ),
                              const SizedBox(height: 12),
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
          );
        },
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
                      color: AppColors.outline.withOpacity(0.3),
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
