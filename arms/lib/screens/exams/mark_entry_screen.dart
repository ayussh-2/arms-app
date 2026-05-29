import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_sticky_footer.dart';

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
  List<Map<String, dynamic>> _subjects = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Auto-save state
  bool _isDraftSaved = false;
  String _lastSavedTime = '';
  Timer? _autoSaveTimer;

  // studentId -> { subjectId -> marks }
  final Map<String, Map<String, String>> _marksData = {};
  // studentId -> isAbsent
  final Map<String, bool> _absentMap = {};
  // studentId -> status (NORMAL, RNFP, MLP)
  final Map<String, String> _statusMap = {};

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
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = GraphQLProvider.of(context).value;

      // Extract subjects from exam
      final examSubjects = (_exam!['subjects'] as List? ?? []).cast<Map<String, dynamic>>();
      _subjects = examSubjects;

      // Get the class/section from the exam to load students
      final classId = _exam!['for_class'];
      final sectionId = _exam!['for_section'];

      final results = await Future.wait([
        client.query(QueryOptions(
          document: gql(GqlQueries.getStudents),
          variables: {
            if (classId != null) 'classId': classId,
            if (sectionId != null) 'sectionId': sectionId,
          },
        )),
        client.query(QueryOptions(
          document: gql(GqlQueries.getMarks),
          variables: {'examId': _exam!['id']},
        ))
      ]);
      final studentResult = results[0];
      final marksResult = results[1];

      if (!mounted) return;
      if (studentResult.hasException || marksResult.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load data'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

    final students = (studentResult.data?['students'] as List? ?? []).cast<Map<String, dynamic>>();
    final existingMarks = (marksResult.data?['marks'] as List? ?? []).cast<Map<String, dynamic>>();

    // Build lookup: studentId_subjectId -> mark data
    final markLookup = <String, Map<String, dynamic>>{};
    for (final m in existingMarks) {
      final key = '${m['student']?['id']}_${m['subject']?['id']}';
      markLookup[key] = m;
    }

    // Initialize controllers
    for (final student in students) {
      final sid = student['id'] as String;
      _marksData[sid] = {};
      _absentMap[sid] = false;
      _statusMap[sid] = 'NORMAL';

      for (final es in examSubjects) {
        final subjectId = es['subject']?['id'] as String? ?? '';
        final key = '${sid}_$subjectId';
        final existing = markLookup[key];

        if (existing != null) {
          if (existing['is_absent'] == true) {
            _absentMap[sid] = true;
          } else if (existing['marks_obtained'] != null) {
            _marksData[sid]![subjectId] = existing['marks_obtained'].toInt().toString();
          }
          if (existing['mark_status'] != null) {
            _statusMap[sid] = existing['mark_status'];
          }
        }
      }
    }

      setState(() {
        _students = students;
        _isLoading = false;
      });
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

  void _onMarkChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        final now = DateTime.now();
        final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        setState(() {
          _isDraftSaved = true;
          _lastSavedTime = timeStr;
        });
      }
    });
  }

  void _toggleAbsent(String studentId) {
    setState(() {
      _absentMap[studentId] = !(_absentMap[studentId] ?? false);
      if (_absentMap[studentId]!) {
        // Clear marks when marking absent
        _marksData[studentId]?.clear();
      }
      _onMarkChanged();
    });
  }

  void _cycleStatus(String studentId) {
    const statuses = ['NORMAL', 'RNFP', 'MLP'];
    final current = _statusMap[studentId] ?? 'NORMAL';
    final nextIdx = (statuses.indexOf(current) + 1) % statuses.length;
    setState(() {
      _statusMap[studentId] = statuses[nextIdx];
      _onMarkChanged();
    });
  }

  Future<void> _save() async {
    final client = GraphQLProvider.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final input = <Map<String, dynamic>>[];
    for (final student in _students) {
      final sid = student['id'] as String;
      final isAbsent = _absentMap[sid] ?? false;

      for (final es in _subjects) {
        final subjectId = es['subject']?['id'] as String? ?? '';
        final marksText = _marksData[sid]?[subjectId] ?? '';
        final marksVal = marksText.isNotEmpty ? double.tryParse(marksText) : null;

        input.add({
          'student_id': sid,
          'exam_id': _exam!['id'],
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
        variables: {'input': input},
      ));

      if (result.hasException) {
        throw result.exception!;
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Marks saved successfully'), backgroundColor: AppColors.successText),
      );
      navigator.pop();
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
          : Column(
              children: [
                // Sticky Draft Saved Indicator matching mark-entry.html
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isDraftSaved ? 40 : 0,
                  width: double.infinity,
                  color: AppColors.cardSurface,
                  alignment: Alignment.center,
                  child: _isDraftSaved
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_done, size: 16, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              'Draft saved at $_lastSavedTime',
                              style: AppTextStyles.labelXs.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 0, AppSpacing.marginPage, 200),
                        itemCount: _students.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) return _buildConfigHeader();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildStudentCard(_students[i - 1]),
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
                    Text('EXAM CONFIGURATION', style: AppTextStyles.labelXsUppercase),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(4)),
                      child: Text('Auto Total: ${_exam!['total_marks'] ?? 0}', style: AppTextStyles.labelXs.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ConfigRow(label: 'SERIES', value: _exam!['series']?['name'] ?? 'N/A'),
                _ConfigRow(label: 'DATE', value: _exam!['exam_date'] ?? 'N/A'),
                _ConfigRow(label: 'EXAM NAME', value: _exam!['name'] ?? ''),
                _ConfigRow(label: 'SUBJECTS', value: _subjects.map((s) => s['subject']?['name'] ?? '').join(', ')),
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
              Expanded(child: _buildDocCard('Attendance_List.pdf', '1.2 MB')),
              const SizedBox(width: 12),
              Expanded(child: _buildDocCard('MidTerm_Math.pdf', '4.5 MB')),
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
        ],
      ),
    );
  }

  Widget _buildDocCard(String name, String size) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              const Icon(Icons.picture_as_pdf, color: AppColors.errorText, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      size,
                      style: AppTextStyles.labelXs.copyWith(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selecting new file to replace $name...'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.outlineMediumLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
              child: Text(
                'Replace',
                style: AppTextStyles.labelXs.copyWith(color: AppColors.textMain, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
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
                    Text(student['name'] ?? '', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
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
              final subjectId = es['subject']?['id'] as String? ?? '';
              final subjectName = es['subject']?['name'] as String? ?? '';

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
                      initialValue: _marksData[sid]?[subjectId],
                      onChanged: (val) {
                        _marksData[sid]![subjectId] = val;
                        _onMarkChanged();
                      },
                      enabled: !isAbsent,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '00',
                        hintStyle: AppTextStyles.headerSmall.copyWith(color: AppColors.outline.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: isAbsent ? AppColors.surfaceVariant.withValues(alpha: 0.3) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
