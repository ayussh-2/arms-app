import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/upload_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_sticky_footer.dart';
import '../../widgets/arms_input_field.dart';
import 'exam_edit_details_screen.dart';
import 'excel_upload_modal.dart';

/// Mark entry screen matching mark-entry.html.
/// Shows student cards with subject-wise mark inputs, absent toggle, reference documents,
/// sticky draft saved status bar, and real-time auto-saving.
class MarkEntryScreen extends StatefulWidget {
  const MarkEntryScreen({super.key});

  @override
  State<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<MarkEntryScreen> {
  static const int _maxExamPdfSizeBytes = 3 * 1024 * 1024;

  Map<String, dynamic>? _exam;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _schoolsLookup = [];
  List<Map<String, dynamic>> _classesLookup = [];
  List<Map<String, dynamic>> _sectionsLookup = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _searchDebounce;

  final _searchCtrl = TextEditingController();
  late final FocusNode _searchFocusNode;
  late final ScrollController _scrollController;

  // State for dynamic button behavior
  bool _isSearchFocused = true;
  String? _currentEditingStudentId;
  List<FocusNode>? _currentMarkFieldFocusNodes;
  int _currentMarkFieldIndex = 0;

  // Global key for search field to enable scrolling
  final GlobalKey _searchFieldKey = GlobalKey();

  // studentId -> { subjectId -> marks }
  final Map<String, Map<String, String>> _marksData = {};
  // studentId -> { subjectId -> controller }
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  // studentId -> isAbsent
  final Map<String, bool> _absentMap = {};
  // studentId -> status (NORMAL, RNFP, MLP)
  final Map<String, String> _statusMap = {};
  // studentId -> notifier for isAbsent
  final Map<String, ValueNotifier<bool>> _absentNotifierMap = {};
  // studentId -> notifier for status
  final Map<String, ValueNotifier<String>> _statusNotifierMap = {};

  int _currentPage = 0;
  static const int _pageSize = 10;
  static const int _lowEndPageSize = 6;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController();
    _searchCtrl.addListener(_onSearchChanged);

    // FIX 3: Guard setState with a value-equality check — prevents a full
    // rebuild on every focus event when the focused state hasn't changed.
    _searchFocusNode.addListener(() {
      final hasFocus = _searchFocusNode.hasFocus;
      if (_isSearchFocused != hasFocus) {
        setState(() => _isSearchFocused = hasFocus);
      }
      if (hasFocus) _scrollToSearchFieldTop();
    });

    // Auto-focus search field on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
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
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _currentMarkFieldFocusNodes?.forEach((node) => node.dispose());
    for (final notifier in _absentNotifierMap.values) {
      notifier.dispose();
    }
    for (final notifier in _statusNotifierMap.values) {
      notifier.dispose();
    }
    for (final studentControllers in _controllers.values) {
      for (final ctrl in studentControllers.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), _filterStudents);
  }

  Future<void> _loadData() async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final client = GraphQLProvider.of(context).value;

      final lookupsResult = await client.query(QueryOptions(
        document: gql(GqlQueries.getExamLookups),
        variables: {
          'organisationId': orgId,
        },
        fetchPolicy: FetchPolicy.cacheFirst,
      ));

      if (lookupsResult.data != null) {
        final lookups = lookupsResult.data!['getExamLookups'];
        if (lookups != null) {
          _schoolsLookup = (lookups['schools'] as List? ?? []).cast<Map<String, dynamic>>();
          _classesLookup = (lookups['classes'] as List? ?? []).cast<Map<String, dynamic>>();
          _sectionsLookup = (lookups['sections'] as List? ?? []).cast<Map<String, dynamic>>();
        }
      }

      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getExamDetails),
        variables: {
          'examId': _exam!['id'],
          'organisationId': orgId,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (!mounted) return;
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load exam details: ${result.exception.toString()}'),
            backgroundColor: AppColors.errorText,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final details = result.data?['getExamDetails'] as Map<String, dynamic>?;
      if (details != null) {
        final examData = details['exam'] as Map<String, dynamic>?;
        final students = (details['students'] as List? ?? []).cast<Map<String, dynamic>>();
        final existingMarks = (details['marks'] as List? ?? []).cast<Map<String, dynamic>>();
        final subjects = (details['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

        if (examData != null) {
          final oldExam = _exam;
          if (oldExam != null) {
            final merged = {
              ...oldExam,
              ...examData,
              'subjects': subjects,
            };
            oldExam.clear();
            oldExam.addAll(merged);
          } else {
            _exam = {
              ...examData,
              'subjects': subjects,
            };
          }
        }
        _subjects = subjects;

        // Build lookup: studentId_subjectId -> mark data
        final markLookup = <String, Map<String, dynamic>>{};
        for (final m in existingMarks) {
          final key = '${m['student_id']}_${m['subject_id']}';
          markLookup[key] = m;
        }

        // FIX 1: Pre-build a per-student lookup map ONCE before sorting.
        // The original code called .where() on the full existingMarks list
        // inside the comparator, making the sort O(n²·m). With this map the
        // sort is O(n log n) and the pre-build is a single O(m) pass.
        final marksByStudent = <String, List<Map<String, dynamic>>>{};
        for (final m in existingMarks) {
          marksByStudent.putIfAbsent(m['student_id'] as String, () => []).add(m);
        }

        students.sort((a, b) {
          final aId = a['id'] as String;
          final bId = b['id'] as String;

          final aStudentMarks = marksByStudent[aId] ?? [];
          final bStudentMarks = marksByStudent[bId] ?? [];

          final aAbsent = aStudentMarks.any((m) => m['is_absent'] == true);
          final bAbsent = bStudentMarks.any((m) => m['is_absent'] == true);
          if (aAbsent && bAbsent) return 0;
          if (aAbsent) return 1;
          if (bAbsent) return -1;

          final aMarksList = aStudentMarks
              .map((m) => m['marks_obtained'] as num?)
              .whereType<num>()
              .toList();
          final bMarksList = bStudentMarks
              .map((m) => m['marks_obtained'] as num?)
              .whereType<num>()
              .toList();

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
          _absentNotifierMap[sid]?.dispose();
          _statusNotifierMap[sid]?.dispose();
          _absentNotifierMap[sid] = ValueNotifier<bool>(false);
          _statusNotifierMap[sid] = ValueNotifier<String>('NORMAL');

          for (final es in _subjects) {
            final subjectId = es['id'] as String? ?? '';
            final key = '${sid}_$subjectId';
            final existing = markLookup[key];

            String markVal = '';
            if (existing != null) {
              if (existing['is_absent'] == true) {
                _absentMap[sid] = true;
                _absentNotifierMap[sid]?.value = true;
              } else if (existing['marks_obtained'] != null) {
                markVal = existing['marks_obtained'].toInt().toString();
                _marksData[sid]![subjectId] = markVal;
              }
              if (existing['mark_status'] != null) {
                _statusMap[sid] = existing['mark_status'];
                _statusNotifierMap[sid]?.value = existing['mark_status'];
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSearchFieldTop();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: AppColors.errorText),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleAbsent(String studentId) {
    final nextValue = !(_absentMap[studentId] ?? false);
    _absentMap[studentId] = nextValue;
    _absentNotifierMap[studentId]?.value = nextValue;
    if (nextValue) {
      // Clear marks when marking absent
      _marksData[studentId]?.clear();
      _controllers[studentId]?.values.forEach((ctrl) => ctrl.clear());
    }
  }

  void _cycleStatus(String studentId) {
    const statuses = ['NORMAL', 'RNFP', 'MLP'];
    final current = _statusMap[studentId] ?? 'NORMAL';
    final nextIdx = (statuses.indexOf(current) + 1) % statuses.length;
    final nextValue = statuses[nextIdx];
    _statusMap[studentId] = nextValue;
    _statusNotifierMap[studentId]?.value = nextValue;
  }

  void _navigateToMarkFields() {
    if (_filteredStudents.isEmpty) return;

    final firstStudent = _filteredStudents.first;
    final studentId = firstStudent['id'] as String;

    setState(() {
      _currentEditingStudentId = studentId;
      _currentMarkFieldIndex = 0;
    });

    // FIX 6: Dispose previous FocusNodes before allocating new ones.
    // Without this, every call to _navigateToMarkFields leaked the previous
    // set of nodes as live listeners until the screen was destroyed.
    _currentMarkFieldFocusNodes?.forEach((node) => node.dispose());
    _currentMarkFieldFocusNodes = List.generate(
      _subjects.length,
      (index) {
        final node = FocusNode();
        node.addListener(() {
          if (node.hasFocus) _scrollFocusedFieldIntoView(node);
        });
        return node;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentMarkFieldFocusNodes != null &&
          _currentMarkFieldFocusNodes!.isNotEmpty) {
        _currentMarkFieldFocusNodes!.first.requestFocus();
      }
      final searchContext = _searchFieldKey.currentContext;
      if (searchContext != null) {
        Scrollable.ensureVisible(
          searchContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    });
  }

  bool _areAllMarksEntered() {
    if (_currentEditingStudentId == null) return false;
    final isAbsent = _absentMap[_currentEditingStudentId] ?? false;
    if (isAbsent) return true; // Absent students don't need marks
    for (final subject in _subjects) {
      final subjectId = subject['id'] as String? ?? '';
      final marksText = _marksData[_currentEditingStudentId]?[subjectId] ?? '';
      if (marksText.isEmpty) return false;
    }
    return true;
  }

  // FIX 2: Guard setState so it only fires when the editing state truly
  // changes. The original code called setState on EVERY keystroke via
  // onChanged → _handleMarkEntryCompletion, rebuilding the entire widget tree
  // each time. Now setState is skipped if no active editing session exists.
  void _handleMarkEntryCompletion() {
    if (_currentEditingStudentId == null) return; // Nothing active — skip entirely
    if (_areAllMarksEntered()) {
      setState(() {
        _currentEditingStudentId = null;
        _isSearchFocused = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusSearchField());
    }
  }

  void _handleActionButtonPressed(BuildContext context) {
    final keyboardOpen = _isKeyboardOpen(context);
    if (keyboardOpen) {
      if (_isSearchFocused) {
        _navigateToMarkFields();
      } else {
        _focusNextMarkField();
      }
    } else {
      _save();
    }
  }

  void _focusNextMarkField() {
    if (_currentEditingStudentId == null || _currentMarkFieldFocusNodes == null) {
      _focusSearchField();
      return;
    }
    final focusNodes = _currentMarkFieldFocusNodes!;
    if (focusNodes.isEmpty) {
      _focusSearchField();
      return;
    }
    if (_currentMarkFieldIndex < focusNodes.length - 1) {
      _currentMarkFieldIndex += 1;
      focusNodes[_currentMarkFieldIndex].requestFocus();
      return;
    }
    // We are at the last field — always return to search.
    _currentEditingStudentId = null;
    _currentMarkFieldIndex = 0;
    _focusSearchField();
  }

  bool _isKeyboardOpen(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  void _focusSearchField() {
    _searchFocusNode.requestFocus();
    _scrollToSearchField();
  }

  void _scrollToSearchField() {
    final searchContext = _searchFieldKey.currentContext;
    if (searchContext != null) {
      Scrollable.ensureVisible(
        searchContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  void _scrollToSearchFieldTop() {
    final searchContext = _searchFieldKey.currentContext;
    if (searchContext != null) {
      Scrollable.ensureVisible(
        searchContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  void _scrollFocusedFieldIntoView(FocusNode node) {
    final fieldContext = node.context;
    if (fieldContext == null) return;
    Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );
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
              content: Text(
                'Error: Marks for ${student['name']} in ${es['name']} exceed maximum marks ($maxMarks)',
              ),
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

      if (result.hasException) throw result.exception!;

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Marks saved successfully'),
          backgroundColor: AppColors.successText,
        ),
      );
      navigator.pop(true); // Return true to trigger refresh
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
    final keyboardOpen = _isKeyboardOpen(context);

    // FIX 5: Compute item width once here in build() and pass it down as a
    // plain double. Previously MediaQuery was called inside every subject's
    // SizedBox inside every student card — O(students × subjects) calls per
    // frame. Now it is one call per build pass.
    final media = MediaQuery.of(context);
    final itemWidth = (media.size.width - 80) / 2;
    final effectivePageSize = media.size.shortestSide < 360
        ? _lowEndPageSize
        : _pageSize;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(title: 'Marks Entry', showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                Builder(
                  builder: (context) {
                    final pageStudents = _filteredStudents
                        .skip(_currentPage * effectivePageSize)
                        .take(effectivePageSize)
                        .toList();
                    return ListView.builder(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.marginPage, 0, AppSpacing.marginPage, 200),
                      itemCount: pageStudents.length + 2,
                      itemBuilder: (_, i) {
                        if (i == 0) return _buildConfigHeader();
                        if (i == pageStudents.length + 1) {
                          if (_filteredStudents.length <= effectivePageSize) {
                            return const SizedBox(height: 120);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Showing ${(_currentPage * effectivePageSize) + 1} to '
                                  '${((_currentPage + 1) * effectivePageSize).clamp(1, _filteredStudents.length)} '
                                  'of ${_filteredStudents.length}',
                                  style: AppTextStyles.labelXs
                                      .copyWith(color: AppColors.onSurfaceVariant),
                                ),
                                Row(
                                  children: [
                                    _PaginationButton(
                                      icon: Icons.chevron_left,
                                      isEnabled: _currentPage > 0,
                                      onTap: () => setState(() => _currentPage--),
                                    ),
                                    const SizedBox(width: 8),
                                    _PaginationButton(
                                      icon: Icons.chevron_right,
                                      isEnabled: (_currentPage + 1) *
                                              effectivePageSize <
                                          _filteredStudents.length,
                                      onTap: () => setState(() => _currentPage++),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        final student = pageStudents[i - 1];
                        final sid = student['id'] as String;

                        // FIX 4: _StudentCard is a StatelessWidget instead of a
                        // plain method call. Flutter can now reconcile each card
                        // independently so an absent-toggle or status-cycle on
                        // one student doesn't force every other card to rebuild.
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: RepaintBoundary(
                            child: _StudentCard(
                              key: ValueKey(sid),
                              student: student,
                              slNo: (_currentPage * effectivePageSize) + i,
                              absentListenable: _absentNotifierMap[sid]!,
                              statusListenable: _statusNotifierMap[sid]!,
                              controllers: _controllers[sid] ?? {},
                              subjects: _subjects,
                              isEditing: _currentEditingStudentId == sid,
                              focusNodes: _currentEditingStudentId == sid
                                  ? _currentMarkFieldFocusNodes
                                  : null,
                              itemWidth: itemWidth,
                              onAbsentToggle: () => _toggleAbsent(sid),
                              onStatusCycle: () => _cycleStatus(sid),
                              onMarkChanged: (subjectId, val) {
                                _marksData[sid]![subjectId] = val;
                                _handleMarkEntryCompletion();
                              },
                            ),
                          ),
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
                    primaryButtonText: _isSaving
                        ? 'Saving...'
                        : (keyboardOpen ? 'Next' : 'Save & Close'),
                    onPrimaryPressed: _isSaving
                        ? () {}
                        : () => _handleActionButtonPressed(context),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openExcelUploadModal(BuildContext context) async {
    if (_exam == null) return;

    final Map<String, Map<String, String>>? importedMarks = await showDialog<Map<String, Map<String, String>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExcelMarksUploadModal(
        exam: _exam!,
        subjects: _subjects,
        students: _students,
        schoolsLookup: _schoolsLookup,
        classesLookup: _classesLookup,
        sectionsLookup: _sectionsLookup,
      ),
    );

    if (importedMarks != null && mounted) {
      setState(() {
        importedMarks.forEach((studentId, subjectMarks) {
          if (_absentMap[studentId] == true) {
            _absentMap[studentId] = false;
            _absentNotifierMap[studentId]?.value = false;
          }

          subjectMarks.forEach((subjectId, score) {
            _marksData.putIfAbsent(studentId, () => {})[subjectId] = score;

            final ctrl = _controllers[studentId]?[subjectId];
            if (ctrl != null) {
              ctrl.text = score;
            }
          });
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Marks imported from Excel successfully!'),
            ],
          ),
          backgroundColor: AppColors.successText,
        ),
      );
    }
  }

  Widget _buildConfigHeader() {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.stackMd, bottom: AppSpacing.stackLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam configuration details card
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
                      onTap: () async {
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExamEditDetailsScreen(
                              exam: _exam!,
                              subjects: _subjects,
                              schoolsLookup: _schoolsLookup,
                              classesLookup: _classesLookup,
                              sectionsLookup: _sectionsLookup,
                            ),
                          ),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _exam!['name'] = result['name'];
                            _exam!['chapter'] = result['chapter'];
                            _exam!['topic'] = result['topic'];
                            _exam!['exam_date'] = result['exam_date'];
                            _exam!['for_school'] = result['for_school'];
                            _exam!['for_class'] = result['for_class'];
                            _exam!['for_section'] = result['for_section'];
                            _exam!['total_marks'] = result['total_marks'];

                            final updatedMarks = result['subject_marks'] as Map<String, int>? ?? {};
                            for (final sub in _subjects) {
                              final subId = sub['id'] as String;
                              if (updatedMarks.containsKey(subId)) {
                                sub['max_marks'] = updatedMarks[subId];
                              }
                            }
                          });
                          _loadData();
                        }
                      },
                      child: const Icon(Icons.edit,
                          size: 16, color: AppColors.primary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Total: ${_exam!['total_marks'] ?? 0}',
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ConfigRow(
                    label: 'SERIES',
                    value: _exam!['series']?['name'] ?? 'N/A'),
                _ConfigRow(
                    label: 'DATE',
                    value: _formatExamDate(_exam!['exam_date'])),
                _ConfigRow(label: 'EXAM NAME', value: _exam!['name'] ?? ''),
                _ConfigRow(
                    label: 'SUBJECTS',
                    value: _subjects
                        .map((s) => s['name'] ?? '')
                        .join(', ')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          // Reference Documents Section
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
                    _exam!['attendance_pdf_url'],
                    'attendance'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDocCardDynamic(
                    'Question Paper',
                    _exam!['question_pdf_url'],
                    'question'),
              ),
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
                onPressed: () => _openExcelUploadModal(context),
                icon: const Icon(Icons.upload_file,
                    size: 16, color: AppColors.primary),
                label: Text(
                  'UPLOAD EXCEL',
                  style: AppTextStyles.labelXs.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999)),
                  backgroundColor: AppColors.primaryFaint,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Container(
            key: _searchFieldKey,
            child: ArmsInputField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              hintText: 'Search students by name or roll number...',
              prefixIcon: Icons.search,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCardDynamic(String title, String? url, String type) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;

    // Extract a readable filename from the URL, or default to a standard name
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
          color:
              hasUrl ? AppColors.outlineLight : AppColors.outlineMediumLight,
        ),
      ),
      child: hasUrl
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf,
                        color: AppColors.errorText, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.labelXs.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            filename,
                            style: AppTextStyles.labelXs.copyWith(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant),
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
                          onPressed: _isSaving ? null : () => _updatePdf(type),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.outlineMediumLight),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999)),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
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
                            final messenger =
                                ScaffoldMessenger.of(context);
                            try {
                              final uri = Uri.parse(url.trim());
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Could not open URL: $e'),
                                  backgroundColor: AppColors.errorText,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryFaint,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999)),
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
              onTap: _isSaving ? null : () => _updatePdf(type),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined,
                          color: AppColors.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    _isSaving ? 'Uploading...' : 'Upload New $title',
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

  String _sanitizeFilename(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();

    return sanitized.isEmpty ? 'exam' : sanitized;
  }

  Future<void> _updatePdf(String type) async {
    if (_exam == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final isAttendance = type == 'attendance';
    final title = isAttendance ? 'Attendance PDF' : 'Question Paper PDF';
    final examId = _exam!['id']?.toString();

    if (examId == null || examId.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Create or open an exam before uploading the PDF'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    final organisationFolder =
        AuthService.currentAdmin?.organization?.name?.trim();
    if (organisationFolder == null || organisationFolder.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('Organisation folder is missing. Please login again.'),
          backgroundColor: AppColors.errorText,
        ),
      );
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to open file picker: $e'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    if (pickerResult == null || pickerResult.files.single.path == null) {
      return;
    }

    final filePath = pickerResult.files.single.path!;
    if (!filePath.toLowerCase().endsWith('.pdf')) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Only PDF uploads are accepted'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    final file = File(filePath);
    final fileSize = await file.length();
    if (fileSize >= _maxExamPdfSizeBytes) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('PDF must be less than 3 MB'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final examName = (_exam!['name'] ?? 'exam').toString();
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

      final client = GraphQLProvider.of(context).value;
      final mutationResult = await client.mutate(MutationOptions(
        document: gql(GqlQueries.updateExamPdfs),
        variables: {
          'examId': examId,
          'attendancePdf':
              isAttendance ? uploadedUrl : _exam!['attendance_pdf_url'],
          'questionPdf':
              !isAttendance ? uploadedUrl : _exam!['question_pdf_url'],
        },
      ));

      if (mutationResult.hasException) throw mutationResult.exception!;

      setState(() {
        if (isAttendance) {
          _exam!['attendance_pdf_url'] = uploadedUrl;
        } else {
          _exam!['question_pdf_url'] = uploadedUrl;
        }
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$title uploaded successfully!'),
            backgroundColor: AppColors.successText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error updating PDF: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


}

// ---------------------------------------------------------------------------
// FIX 4: _StudentCard extracted as a StatelessWidget.
//
// Previously _buildStudentCard was a plain method on _MarkEntryScreenState.
// Every setState() call on the parent (absent toggle, status cycle, search)
// would unconditionally re-invoke the method and rebuild ALL cards on the
// page, even cards whose data had not changed.
//
// As a StatelessWidget with a ValueKey, Flutter's reconciler can skip a card
// entirely when the identity of its key is stable and the parent rebuild
// produces the same widget type at the same slot — cutting redundant work
// proportionally to the number of unchanged cards on screen.
// ---------------------------------------------------------------------------
class _StudentCard extends StatelessWidget {
  const _StudentCard({
    super.key,
    required this.student,
    required this.slNo,
    required this.absentListenable,
    required this.statusListenable,
    required this.controllers,
    required this.subjects,
    required this.isEditing,
    this.focusNodes,
    required this.itemWidth,
    required this.onAbsentToggle,
    required this.onStatusCycle,
    required this.onMarkChanged,
  });

  final Map<String, dynamic> student;
  final int slNo;
  final ValueListenable<bool> absentListenable;
  final ValueListenable<String> statusListenable;
  final Map<String, TextEditingController> controllers;
  final List<Map<String, dynamic>> subjects;
  final bool isEditing;
  final List<FocusNode>? focusNodes;
  // FIX 5: itemWidth is pre-computed in the parent's build() and passed as
  // a plain double so each card no longer subscribes to MediaQuery changes.
  final double itemWidth;
  final VoidCallback onAbsentToggle;
  final VoidCallback onStatusCycle;
  final void Function(String subjectId, String val) onMarkChanged;

  Color _statusColor(String s) {
    switch (s) {
      case 'RNFP':
        return AppColors.accent;
      case 'MLP':
        return AppColors.errorText;
      default:
        return AppColors.surfaceContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: absentListenable,
      builder: (context, isAbsent, _) {
        return ValueListenableBuilder<String>(
          valueListenable: statusListenable,
          builder: (context, status, __) {
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
                            Text(
                              '$slNo. ${student['name'] ?? ''}',
                              style: AppTextStyles.headerSmall
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Roll No: ${student['roll_no'] ?? ''}',
                              style: AppTextStyles.labelXs.copyWith(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Absent toggle
                          GestureDetector(
                            onTap: onAbsentToggle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAbsent
                                    ? AppColors.errorText
                                    : AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: isAbsent
                                      ? AppColors.errorText
                                      : AppColors.outlineLight,
                                ),
                              ),
                              child: Text(
                                isAbsent ? 'ABSENT' : 'MARK ABSENT',
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: isAbsent
                                      ? Colors.white
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Status cycle
                          GestureDetector(
                            onTap: onStatusCycle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                status == 'MLP' ? 'MALPRACTICE' : status,
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: status == 'NORMAL'
                                      ? AppColors.onSurfaceVariant
                                      : Colors.white,
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
                    children: subjects.asMap().entries.map((entry) {
                      final subjectIndex = entry.key;
                      final es = entry.value;
                      final subjectId = es['id'] as String? ?? '';
                      final subjectName = es['name'] as String? ?? '';
                      final maxMarks = es['max_marks'] as num? ?? 100;
                      final controller = controllers[subjectId];

                      FocusNode? markFieldFocusNode;
                      if (isEditing && focusNodes != null) {
                        if (subjectIndex < focusNodes!.length) {
                          markFieldFocusNode = focusNodes![subjectIndex];
                        }
                      }

                      return SizedBox(
                        width: itemWidth, // pre-computed; no MediaQuery call here
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                subjectName.toUpperCase(),
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (controller != null)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: controller,
                                builder: (context, value, _) {
                                  final currentVal =
                                      double.tryParse(value.text);
                                  final isError = currentVal != null &&
                                      currentVal > maxMarks.toDouble();
                                  return TextFormField(
                                    focusNode: markFieldFocusNode,
                                    controller: controller,
                                    onChanged: (val) =>
                                        onMarkChanged(subjectId, val),
                                    enabled: !isAbsent,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.headerSmall.copyWith(
                                        fontWeight: FontWeight.w700),
                                    decoration: InputDecoration(
                                      hintText: '00',
                                      hintStyle: AppTextStyles.headerSmall
                                          .copyWith(
                                              color: AppColors.outline
                                                  .withValues(alpha: 0.5)),
                                      filled: true,
                                      fillColor: isAbsent
                                          ? AppColors.surfaceVariant
                                              .withValues(alpha: 0.3)
                                          : Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      errorText:
                                          isError ? 'Max: $maxMarks' : null,
                                      errorStyle: AppTextStyles.labelXs.copyWith(
                                          color: AppColors.errorText,
                                          fontSize: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AppColors.outlineLight),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AppColors.outlineLight),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AppColors.primary, width: 2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

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
            child: Text(
              label,
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelXs.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple helper to control width without layout errors.
class SpacerPosition extends StatelessWidget {
  const SpacerPosition(
      {super.key, required this.width, required this.child});
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
            border:
                isEnabled ? null : Border.all(color: AppColors.outlineLight),
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

// ---------------------------------------------------------------------------
// Shared helper functions
// ---------------------------------------------------------------------------

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

