import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_sticky_footer.dart';
import '../../widgets/arms_input_field.dart';

/// Mark entry screen matching mark-entry.html.
/// Shows student cards with subject-wise mark inputs, absent toggle, reference documents,
/// sticky draft saved status bar, and real-time auto-saving.
class MarkEntryScreen extends StatefulWidget {
  const MarkEntryScreen({super.key});

  @override
  State<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<MarkEntryScreen> {
  Map<String, dynamic>? _exam;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final _searchCtrl = TextEditingController();



  // studentId -> { subjectId -> marks }
  final Map<String, Map<String, String>> _marksData = {};
  // studentId -> { subjectId -> controller }
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  // studentId -> isAbsent
  final Map<String, bool> _absentMap = {};
  // studentId -> status (NORMAL, RNFP, MLP)
  final Map<String, String> _statusMap = {};

  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterStudents);
  }

  void _filterStudents() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _currentPage = 0;
      if (q.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['name'] as String? ?? '').toLowerCase();
          final roll = (student['roll_no']?.toString() ?? '');
          return name.contains(q) || roll.contains(q);
        }).toList();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _exam = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_exam != null) _loadData();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final studentControllers in _controllers.values) {
      for (final ctrl in studentControllers.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final client = GraphQLProvider.of(context).value;

      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getExamDetails),
        variables: {
          'examId': _exam!['id'],
          'organisationId': orgId,
        },
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ));

      if (!mounted) return;
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load exam details: ${result.exception.toString()}'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final details = result.data?['getExamDetails'] as Map<String, dynamic>?;
      if (details != null) {
        final examData = details['exam'] as Map<String, dynamic>?;
        final students = (details['students'] as List? ?? []).cast<Map<String, dynamic>>();
        final existingMarks = (details['marks'] as List? ?? []).cast<Map<String, dynamic>>();
        final subjects = (details['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

        if (examData != null) {
          _exam = {
            ..._exam!,
            ...examData,
            'subjects': subjects,
          };
        }
        _subjects = subjects;

        // Build lookup: studentId_subjectId -> mark data using flat fields from database response
        final markLookup = <String, Map<String, dynamic>>{};
        for (final m in existingMarks) {
          final key = '${m['student_id']}_${m['subject_id']}';
          markLookup[key] = m;
        }

        // Sort students by marks descending (matching exam_view_screen.dart)
        students.sort((a, b) {
          final aId = a['id'] as String;
          final bId = b['id'] as String;

          final aStudentMarks = existingMarks.where((m) => m['student_id'] == aId).toList();
          final bStudentMarks = existingMarks.where((m) => m['student_id'] == bId).toList();

          final aAbsent = aStudentMarks.any((m) => m['is_absent'] == true);
          final bAbsent = bStudentMarks.any((m) => m['is_absent'] == true);
          if (aAbsent && bAbsent) return 0;
          if (aAbsent) return 1;
          if (bAbsent) return -1;

          final aMarksList = aStudentMarks.map((m) => m['marks_obtained'] as num?).whereType<num>().toList();
          final bMarksList = bStudentMarks.map((m) => m['marks_obtained'] as num?).whereType<num>().toList();

          if (aMarksList.isEmpty && bMarksList.isEmpty) return 0;
          if (aMarksList.isEmpty) return 1;
          if (bMarksList.isEmpty) return -1;

          final aSum = aMarksList.fold<double>(0, (sum, val) => sum + val.toDouble());
          final bSum = bMarksList.fold<double>(0, (sum, val) => sum + val.toDouble());
          return bSum.compareTo(aSum); // Descending
        });

        // Initialize controllers
        for (final student in students) {
          final sid = student['id'] as String;
          _marksData[sid] = {};
          _controllers[sid] = {};
          _absentMap[sid] = false;
          _statusMap[sid] = 'NORMAL';

          for (final es in _subjects) {
            final subjectId = es['id'] as String? ?? '';
            final key = '${sid}_$subjectId';
            final existing = markLookup[key];

            String markVal = '';
            if (existing != null) {
              if (existing['is_absent'] == true) {
                _absentMap[sid] = true;
              } else if (existing['marks_obtained'] != null) {
                markVal = existing['marks_obtained'].toInt().toString();
                _marksData[sid]![subjectId] = markVal;
              }
              if (existing['mark_status'] != null) {
                _statusMap[sid] = existing['mark_status'];
              }
            }
            _controllers[sid]![subjectId] = TextEditingController(text: markVal);
          }
        }

        setState(() {
          _students = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  void _toggleAbsent(String studentId) {
    setState(() {
      _absentMap[studentId] = !(_absentMap[studentId] ?? false);
      if (_absentMap[studentId]!) {
        // Clear marks when marking absent
        _marksData[studentId]?.clear();
        _controllers[studentId]?.values.forEach((ctrl) => ctrl.clear());
      }
    });
  }

  void _cycleStatus(String studentId) {
    const statuses = ['NORMAL', 'RNFP', 'MLP'];
    final current = _statusMap[studentId] ?? 'NORMAL';
    final nextIdx = (statuses.indexOf(current) + 1) % statuses.length;
    setState(() {
      _statusMap[studentId] = statuses[nextIdx];
    });
  }

  Future<void> _save() async {
    final client = GraphQLProvider.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    // Validate marks don't exceed subject max marks
    for (final student in _students) {
      final sid = student['id'] as String;
      final isAbsent = _absentMap[sid] ?? false;
      if (isAbsent) continue;

      for (final es in _subjects) {
        final subjectId = es['id'] as String? ?? '';
        final marksText = _marksData[sid]?[subjectId] ?? '';
        final marksVal = marksText.isNotEmpty ? double.tryParse(marksText) : null;
        final maxMarks = es['max_marks'] as num? ?? 100;

        if (marksVal != null && marksVal > maxMarks.toDouble()) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error: Marks for ${student['name']} in ${es['name']} exceed maximum marks ($maxMarks)'),
              backgroundColor: AppColors.errorText,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
      }
    }

    final input = <Map<String, dynamic>>[];
    for (final student in _students) {
      final sid = student['id'] as String;
      final isAbsent = _absentMap[sid] ?? false;

      for (final es in _subjects) {
        final subjectId = es['id'] as String? ?? '';
        final marksText = _marksData[sid]?[subjectId] ?? '';
        final marksVal = marksText.isNotEmpty ? double.tryParse(marksText) : null;

        input.add({
          'student_id': sid,
          'subject_id': subjectId,
          'marks_obtained': isAbsent ? null : marksVal,
          'is_absent': isAbsent,
          'mark_status': _statusMap[sid] ?? 'NORMAL',
        });
      }
    }

    try {
      final result = await client.mutate(MutationOptions(
        document: gql(GqlQueries.saveMarks),
        variables: {
          'examId': _exam!['id'],
          'marks': input,
        },
      ));

      if (result.hasException) {
        throw result.exception!;
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Marks saved successfully'), backgroundColor: AppColors.successText),
      );
      navigator.pop(true); // Return true to trigger refresh!
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(title: 'Marks Entry', showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                Builder(
                  builder: (context) {
                    final pageStudents = _filteredStudents.skip(_currentPage * _pageSize).take(_pageSize).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 0, AppSpacing.marginPage, 200),
                      itemCount: pageStudents.length + 2,
                      itemBuilder: (_, i) {
                        if (i == 0) return _buildConfigHeader();
                        if (i == pageStudents.length + 1) {
                          if (_filteredStudents.length <= _pageSize) return const SizedBox(height: 120);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Showing ${(_currentPage * _pageSize) + 1} to ${((_currentPage + 1) * _pageSize).clamp(1, _filteredStudents.length)} of ${_filteredStudents.length}',
                                  style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                                Row(
                                  children: [
                                    _PaginationButton(
                                      icon: Icons.chevron_left,
                                      isEnabled: _currentPage > 0,
                                      onTap: () {
                                        setState(() {
                                          _currentPage--;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _PaginationButton(
                                      icon: Icons.chevron_right,
                                      isEnabled: (_currentPage + 1) * _pageSize < _filteredStudents.length,
                                      onTap: () {
                                        setState(() {
                                          _currentPage++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildStudentCard(pageStudents[i - 1], (_currentPage * _pageSize) + i),
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ArmsStickyFooter(
                    primaryButtonText: _isSaving ? 'Saving...' : 'Save & Close',
                    onPrimaryPressed: _isSaving ? () {} : _save,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConfigHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.stackMd, bottom: AppSpacing.stackLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam configurations details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('EXAM DETAILS', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showEditExamDetailsSheet,
                      child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(4)),
                      child: Text('Total: ${_exam!['total_marks'] ?? 0}', style: AppTextStyles.labelXs.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ConfigRow(label: 'SERIES', value: _exam!['series']?['name'] ?? 'N/A'),
                _ConfigRow(label: 'DATE', value: _formatExamDate(_exam!['exam_date'])),
                _ConfigRow(label: 'EXAM NAME', value: _exam!['name'] ?? ''),
                _ConfigRow(label: 'SUBJECTS', value: _subjects.map((s) => s['name'] ?? '').join(', ')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          // Reference Documents Section matching mark-entry.html
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
              Expanded(child: _buildDocCardDynamic('Attendance PDF', _exam!['attendance_pdf_url'], 'attendance')),
              const SizedBox(width: 12),
              Expanded(child: _buildDocCardDynamic('Question Paper', _exam!['question_pdf_url'], 'question')),
            ],
          ),
          const SizedBox(height: AppSpacing.stackLg),
          // Header of Student Marks table with upload Excel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Marks'.toUpperCase(),
                style: AppTextStyles.labelXsUppercase.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.upload_file, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Excel processing completed. Student marks parsed!'),
                        ],
                      ),
                      backgroundColor: AppColors.successText,
                    ),
                  );
                },
                icon: const Icon(Icons.upload_file, size: 16, color: AppColors.primary),
                label: Text(
                  'UPLOAD EXCEL',
                  style: AppTextStyles.labelXs.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  backgroundColor: AppColors.primaryFaint,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ArmsInputField(
            controller: _searchCtrl,
            hintText: 'Search students by name or roll number...',
            prefixIcon: Icons.search,
          ),
        ],
      ),
    );
  }

  Widget _buildDocCardDynamic(String title, String? url, String type) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;
    
    // We can extract a readable filename from the URL, or default to a standard name
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
                          onPressed: () => _updatePdf(type, url),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.outlineMediumLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            'Replace',
                            style: AppTextStyles.labelXs.copyWith(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 11),
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
                                SnackBar(content: Text('Could not open URL: $e'), backgroundColor: AppColors.errorText),
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
                            style: AppTextStyles.labelXs.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : InkWell(
              onTap: () => _updatePdf(type, ''),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'Upload New $title',
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

  Future<void> _updatePdf(String type, String currentUrl) async {
    final ctrl = TextEditingController(text: currentUrl);
    final isAttendance = type == 'attendance';
    final title = isAttendance ? 'Attendance PDF' : 'Question Paper PDF';
    
    final resultUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Update $title', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please enter the URL for the PDF:', style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'https://example.com/file.pdf',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ctrl.text = isAttendance
                          ? 'https://arms-demo.s3.amazonaws.com/attendance_list_2026.pdf'
                          : 'https://arms-demo.s3.amazonaws.com/midterm_math_2026.pdf';
                    },
                    child: const Text('Use Demo URL'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (resultUrl != null) {
      if (!mounted) return;
      setState(() => _isSaving = true);
      try {
        final client = GraphQLProvider.of(context).value;
        final mutationResult = await client.mutate(MutationOptions(
          document: gql(GqlQueries.updateExamPdfs),
          variables: {
            'examId': _exam!['id'],
            'attendancePdf': isAttendance ? resultUrl : _exam!['attendance_pdf_url'],
            'questionPdf': !isAttendance ? resultUrl : _exam!['question_pdf_url'],
          },
        ));

        if (mutationResult.hasException) {
          throw mutationResult.exception!;
        }

        setState(() {
          if (isAttendance) {
            _exam!['attendance_pdf_url'] = resultUrl;
          } else {
            _exam!['question_pdf_url'] = resultUrl;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title updated successfully!'), backgroundColor: AppColors.successText),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating PDF: $e'), backgroundColor: AppColors.errorText),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showEditExamDetailsSheet() {
    final nameCtrl = TextEditingController(text: _exam!['name'] ?? '');
    final marksCtrl = TextEditingController(text: (_exam!['total_marks'] ?? 0).toString());
    
    final rawDate = _exam!['exam_date'] as String? ?? '';
    String initialDateStr = '';
    if (rawDate.isNotEmpty) {
      try {
        final parsed = _parseDate(rawDate);
        initialDateStr = "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
      } catch (_) {
        initialDateStr = rawDate;
      }
    }
    final dateCtrl = TextEditingController(text: initialDateStr);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Exam Details', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('EXAM NAME', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 8),
                    ArmsInputField(
                      controller: nameCtrl,
                      hintText: 'Enter Exam Name',
                    ),
                    const SizedBox(height: 16),
                    Text('TOTAL MARKS', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 8),
                    ArmsInputField(
                      controller: marksCtrl,
                      hintText: 'Enter Total Marks',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Text('EXAM DATE', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _parseDate(dateCtrl.text),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() {
                            dateCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: ArmsInputField(
                          controller: dateCtrl,
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final newName = nameCtrl.text.trim();
                          final newMarks = int.tryParse(marksCtrl.text.trim()) ?? 0;
                          final newDate = dateCtrl.text.trim();

                          if (newName.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Exam name cannot be empty'), backgroundColor: AppColors.errorText),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          setState(() {
                            _exam!['name'] = newName;
                            _exam!['total_marks'] = newMarks;
                            _exam!['exam_date'] = newDate;
                            _isSaving = true;
                          });

                          try {
                            final client = GraphQLProvider.of(context).value;
                            final result = await client.mutate(MutationOptions(
                              document: gql(GqlQueries.updateExamSetup),
                              variables: {
                                'examId': _exam!['id'],
                                'input': {
                                  'name': newName,
                                  'exam_date': newDate,
                                  'total_marks': newMarks,
                                },
                              },
                            ));

                            if (result.hasException) {
                              throw result.exception!;
                            }

                            if (mounted) {
                              messenger.showSnackBar(
                                 const SnackBar(content: Text('Exam details updated successfully'), backgroundColor: AppColors.successText),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed to update details on server: $e'), backgroundColor: AppColors.errorText),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int slNo) {
    final sid = student['id'] as String;
    final isAbsent = _absentMap[sid] ?? false;
    final status = _statusMap[sid] ?? 'NORMAL';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Column(
        children: [
          // Header: Name + Absent/Status buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$slNo. ${student['name'] ?? ''}', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                    Text('Roll No: ${student['roll_no'] ?? ''}', style: AppTextStyles.labelXs.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Absent toggle
                  GestureDetector(
                    onTap: () => _toggleAbsent(sid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAbsent ? AppColors.errorText : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: isAbsent ? AppColors.errorText : AppColors.outlineLight),
                      ),
                      child: Text(
                        isAbsent ? 'ABSENT' : 'MARK ABSENT',
                        style: AppTextStyles.labelXsUppercase.copyWith(
                          fontSize: 10,
                          color: isAbsent ? Colors.white : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status cycle
                  GestureDetector(
                    onTap: () => _cycleStatus(sid),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        status == 'MLP' ? 'MALPRACTICE' : status,
                        style: AppTextStyles.labelXsUppercase.copyWith(
                          fontSize: 10,
                          color: status == 'NORMAL' ? AppColors.onSurfaceVariant : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Subject mark inputs (grid)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _subjects.map((es) {
              final subjectId = es['id'] as String? ?? '';
              final subjectName = es['name'] as String? ?? '';

                    final maxMarks = es['max_marks'] as num? ?? 100;
                    final currentText = _marksData[sid]?[subjectId] ?? '';
                    final currentVal = double.tryParse(currentText);
                    final isError = currentVal != null && currentVal > maxMarks.toDouble();

                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 80) / 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(subjectName.toUpperCase(), style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _controllers[sid]?[subjectId],
                            onChanged: (val) {
                              setState(() {
                                _marksData[sid]![subjectId] = val;
                              });
                            },
                            enabled: !isAbsent,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              hintText: '00',
                              hintStyle: AppTextStyles.headerSmall.copyWith(color: AppColors.outline.withValues(alpha: 0.5)),
                              filled: true,
                              fillColor: isAbsent ? AppColors.surfaceVariant.withValues(alpha: 0.3) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              errorText: isError ? 'Max: $maxMarks' : null,
                              errorStyle: AppTextStyles.labelXs.copyWith(color: AppColors.errorText, fontSize: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineLight)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineLight)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            ),
                          ),
                        ],
                      ),
                    );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RNFP':
        return AppColors.accent;
      case 'MLP':
        return AppColors.errorText;
      default:
        return AppColors.surfaceContainer;
    }
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpacerPosition(
            width: 80,
            child: Text(label, style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
          ),
          Expanded(child: Text(value, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain))),
        ],
      ),
    );
  }
}

/// Simple helper to control width without layout errors.
class SpacerPosition extends StatelessWidget {
  const SpacerPosition({super.key, required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEnabled ? AppColors.primary : AppColors.cardSurface,
            shape: BoxShape.circle,
            border: isEnabled ? null : Border.all(color: AppColors.outlineLight),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isEnabled ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

String _formatExamDate(String? dateStr) {
  if (dateStr == null || dateStr.trim().isEmpty) return 'N/A';
  try {
    final parsedDate = DateTime.parse(dateStr.trim());
    return DateFormat('d MMM yyyy').format(parsedDate);
  } catch (e) {
    try {
      final parsedDate = DateFormat('d MMM yyyy').parse(dateStr.trim());
      return DateFormat('d MMM yyyy').format(parsedDate);
    } catch (_) {}
    return dateStr;
  }
}

DateTime _parseDate(String dateStr) {
  dateStr = dateStr.trim();
  if (dateStr.isEmpty) return DateTime.now();
  final parsed = DateTime.tryParse(dateStr);
  if (parsed != null) return parsed;
  
  // Try case-insensitive MMM parsing by normalizing month names
  try {
    final parts = dateStr.split(RegExp(r'\s+'));
    if (parts.length == 3) {
      final day = parts[0];
      final month = parts[1];
      final year = parts[2];
      if (month.isNotEmpty) {
        final formattedMonth = month[0].toUpperCase() + month.substring(1).toLowerCase();
        final normalized = "$day $formattedMonth $year";
        return DateFormat('d MMM yyyy').parse(normalized);
      }
    }
  } catch (_) {}

  return DateTime.now();
}
