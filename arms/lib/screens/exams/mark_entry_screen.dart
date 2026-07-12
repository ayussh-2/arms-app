import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_sticky_footer.dart';
import '../../widgets/components/arms_input_field.dart';
import '../../widgets/arms_snackbar.dart';
import 'widgets/mark_entry_grid.dart';
import 'widgets/exam_config_header_panel.dart';
import 'widgets/exam_reference_docs_section.dart';
import 'excel_upload_screen.dart';

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
  List<Map<String, dynamic>> _schoolsLookup = [];
  List<Map<String, dynamic>> _classesLookup = [];
  List<Map<String, dynamic>> _sectionsLookup = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _searchDebounce;

  final _searchCtrl = TextEditingController();
  late final FocusNode _searchFocusNode;
  late final ScrollController _scrollController;

  bool _isSearchFocused = true;
  String? _currentEditingStudentId;
  List<FocusNode>? _currentMarkFieldFocusNodes;
  int _currentMarkFieldIndex = 0;

  final GlobalKey _searchFieldKey = GlobalKey();

  final Map<String, Map<String, String>> _marksData = {};
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  final Map<String, bool> _absentMap = {};
  final Map<String, String> _statusMap = {};
  final Map<String, ValueNotifier<bool>> _absentNotifierMap = {};
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

    _searchFocusNode.addListener(() {
      final hasFocus = _searchFocusNode.hasFocus;
      if (_isSearchFocused != hasFocus) {
        setState(() => _isSearchFocused = hasFocus);
      }
      if (hasFocus) _scrollToSearchFieldTop();
    });

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
        _filteredStudents =
            _students.where((student) {
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
      _exam =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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

      final lookupsResult = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExamLookups),
          variables: {'organisationId': orgId},
          fetchPolicy: FetchPolicy.cacheFirst,
        ),
      );

      if (lookupsResult.data != null) {
        final lookups = lookupsResult.data!['getExamLookups'];
        if (lookups != null) {
          _schoolsLookup =
              (lookups['schools'] as List? ?? []).cast<Map<String, dynamic>>();
          _classesLookup =
              (lookups['classes'] as List? ?? []).cast<Map<String, dynamic>>();
          _sectionsLookup =
              (lookups['sections'] as List? ?? []).cast<Map<String, dynamic>>();
        }
      }

      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExamDetails),
          variables: {'examId': _exam!['id'], 'organisationId': orgId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (!mounted) return;
      if (result.hasException) {
        ArmsSnackbar.showError(
          context,
          'Failed to load exam details: ${result.exception.toString()}',
        );
        setState(() => _isLoading = false);
        return;
      }

      final details = result.data?['getExamDetails'] as Map<String, dynamic>?;
      if (details != null) {
        final examData = details['exam'] as Map<String, dynamic>?;
        final students =
            (details['students'] as List? ?? []).cast<Map<String, dynamic>>();
        final existingMarks =
            (details['marks'] as List? ?? []).cast<Map<String, dynamic>>();
        final subjects =
            (details['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

        if (examData != null) {
          final oldExam = _exam;
          if (oldExam != null) {
            final merged = {...oldExam, ...examData, 'subjects': subjects};
            oldExam.clear();
            oldExam.addAll(merged);
          } else {
            _exam = {...examData, 'subjects': subjects};
          }
        }
        _subjects = subjects;

        final markLookup = <String, Map<String, dynamic>>{};
        for (final m in existingMarks) {
          final key = '${m['student_id']}_${m['subject_id']}';
          markLookup[key] = m;
        }

        final marksByStudent = <String, List<Map<String, dynamic>>>{};
        for (final m in existingMarks) {
          marksByStudent
              .putIfAbsent(m['student_id'] as String, () => [])
              .add(m);
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

          final aMarksList =
              aStudentMarks
                  .map((m) => m['marks_obtained'] as num?)
                  .whereType<num>()
                  .toList();
          final bMarksList =
              bStudentMarks
                  .map((m) => m['marks_obtained'] as num?)
                  .whereType<num>()
                  .toList();

          if (aMarksList.isEmpty && bMarksList.isEmpty) return 0;
          if (aMarksList.isEmpty) return 1;
          if (bMarksList.isEmpty) return -1;

          final aSum = aMarksList.fold<double>(
            0,
            (sum, val) => sum + val.toDouble(),
          );
          final bSum = bMarksList.fold<double>(
            0,
            (sum, val) => sum + val.toDouble(),
          );
          return bSum.compareTo(aSum);
        });

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
            _controllers[sid]![subjectId] = TextEditingController(
              text: markVal,
            );
          }
        }

        setState(() {
          _students = students;
          _filteredStudents = students;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToSearchFieldTop(),
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Connection error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleAbsent(String studentId) {
    final nextValue = !(_absentMap[studentId] ?? false);
    _absentMap[studentId] = nextValue;
    _absentNotifierMap[studentId]?.value = nextValue;
    if (nextValue) {
      _marksData[studentId]?.clear();
      _controllers[studentId]?.values.forEach((ctrl) => ctrl.clear());
    }
  }

  bool _isEligibleForBulkAbsent(String studentId) {
    if (_absentMap[studentId] == true) return false;

    final studentControllers = _controllers[studentId];
    if (studentControllers == null || studentControllers.isEmpty) {
      return true;
    }

    return studentControllers.values.every((controller) {
      return controller.text.trim().isEmpty;
    });
  }

  void _markRestAbsent() {
    if (_students.isEmpty) return;

    final remainingStudents =
        _students.where((student) {
          final studentId = student['id'] as String;
          return _isEligibleForBulkAbsent(studentId);
        }).toList();

    if (remainingStudents.isEmpty) return;

    setState(() {
      _currentEditingStudentId = null;
      _currentMarkFieldIndex = 0;

      for (final student in remainingStudents) {
        final studentId = student['id'] as String;
        _absentMap[studentId] = true;
        _absentNotifierMap[studentId]?.value = true;
        _marksData[studentId]?.clear();
        _controllers[studentId]?.values.forEach((ctrl) => ctrl.clear());
      }
    });

    _currentMarkFieldFocusNodes?.forEach((node) => node.dispose());
    _currentMarkFieldFocusNodes = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusSearchField();
      }
    });
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

    _currentMarkFieldFocusNodes?.forEach((node) => node.dispose());
    _currentMarkFieldFocusNodes = List.generate(_subjects.length, (index) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) _scrollFocusedFieldIntoView(node);
      });
      return node;
    });

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
    if (_currentEditingStudentId == null ||
        _currentMarkFieldFocusNodes == null) {
      _focusSearchField();
      return;
    }
    final focusNodes = _currentMarkFieldFocusNodes!;
    if (focusNodes.isEmpty) {
      _focusSearchField();
      return;
    }
    if (_currentMarkFieldIndex < focusNodes.length - 1) {
      setState(() {
        _currentMarkFieldIndex += 1;
      });
      focusNodes[_currentMarkFieldIndex].requestFocus();
      return;
    }
    setState(() {
      _currentEditingStudentId = null;
      _currentMarkFieldIndex = 0;
    });
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
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    for (final student in _students) {
      final sid = student['id'] as String;
      final isAbsent = _absentMap[sid] ?? false;
      if (isAbsent) continue;

      for (final es in _subjects) {
        final subjectId = es['id'] as String? ?? '';
        final marksText = _marksData[sid]?[subjectId] ?? '';
        final marksVal =
            marksText.isNotEmpty ? double.tryParse(marksText) : null;
        final maxMarks = es['max_marks'] as num? ?? 100;

        if (marksVal != null && marksVal > maxMarks.toDouble()) {
          ArmsSnackbar.showError(
            context,
            'Error: Marks for ${student['name']} in ${es['name']} exceed maximum marks ($maxMarks)',
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
        final marksVal =
            marksText.isNotEmpty ? double.tryParse(marksText) : null;

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
      final result = await client.mutate(
        MutationOptions(
          document: gql(GqlQueries.saveMarks),
          variables: {'examId': _exam!['id'], 'marks': input},
        ),
      );

      if (result.hasException) throw result.exception!;

      if (!mounted) return;
      ArmsSnackbar.showSuccess(context, 'Marks saved successfully');
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      ArmsSnackbar.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openExcelUploadScreen(BuildContext context) async {
    if (_exam == null) return;

    final Map<String, Map<String, String>>? importedMarks =
        await Navigator.push<Map<String, Map<String, String>>>(
          context,
          MaterialPageRoute(
            builder:
                (context) => ExcelMarksUploadScreen(
                  exam: _exam!,
                  subjects: _subjects,
                  students: _students,
                  schoolsLookup: _schoolsLookup,
                  classesLookup: _classesLookup,
                  sectionsLookup: _sectionsLookup,
                ),
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

      if (!context.mounted) return;
      ArmsSnackbar.showSuccess(
        context,
        'Marks imported from Excel successfully!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = _isKeyboardOpen(context);
    final media = MediaQuery.of(context);
    final itemWidth = (media.size.width - 80) / 2;
    final effectivePageSize =
        media.size.shortestSide < 360 ? _lowEndPageSize : _pageSize;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(title: 'Marks Entry', showBackButton: true),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : Stack(
                children: [
                  ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.marginPage,
                      AppSpacing.stackMd,
                      AppSpacing.marginPage,
                      100,
                    ),
                    children: [
                      ExamConfigHeaderPanel(
                        exam: _exam!,
                        subjects: _subjects,
                        schoolsLookup: _schoolsLookup,
                        classesLookup: _classesLookup,
                        sectionsLookup: _sectionsLookup,
                        onExamDetailsUpdated: () => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      ExamReferenceDocsSection(
                        exam: _exam!,
                        onPdfUploaded: (type, newUrl) {
                          setState(() {
                            if (type == 'attendance') {
                              _exam!['attendance_pdf_url'] = newUrl;
                            } else {
                              _exam!['question_pdf_url'] = newUrl;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          Text(
                            'Student Marks'.toUpperCase(),
                            style: AppTextStyles.labelXsUppercase.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    () => _openExcelUploadScreen(context),
                                icon: const Icon(
                                  Icons.upload_file,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  'UPLOAD EXCEL',
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: AppColors.primaryFaint,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  // foregroundColor: AppColors.primary,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _students.any((student) {
                                          final studentId =
                                              student['id'] as String;
                                          return _isEligibleForBulkAbsent(
                                            studentId,
                                          );
                                        })
                                        ? _markRestAbsent
                                        : null,
                                icon: const Icon(
                                  Icons.block,
                                  size: 16,
                                  color: AppColors.errorText,
                                ),
                                label: Text(
                                  'MARK REST STUDENTS ABSENT',
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: AppColors.errorText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.errorText.withValues(
                                      alpha: 0.35,
                                    ),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: AppColors.errorText
                                      .withValues(alpha: 0.06),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
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
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _navigateToMarkFields(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MarkEntryGrid(
                        students:
                            _filteredStudents
                                .skip(_currentPage * effectivePageSize)
                                .take(effectivePageSize)
                                .toList(),
                        subjects: _subjects,
                        controllers: _controllers,
                        absentNotifiers: _absentNotifierMap,
                        statusNotifiers: _statusNotifierMap,
                        isEditing: _currentEditingStudentId != null,
                        focusNodes: _currentMarkFieldFocusNodes,
                        itemWidth: itemWidth,
                        currentPage: _currentPage,
                        pageSize: effectivePageSize,
                        currentEditingStudentId: _currentEditingStudentId,
                        onMarkChanged: (studentId, subId, val) {
                          _marksData.putIfAbsent(studentId, () => {})[subId] =
                              val;
                        },
                        onAbsentToggle: _toggleAbsent,
                        onStatusCycle: _cycleStatus,
                        onNext: _focusNextMarkField,
                      ),
                      if (_filteredStudents.length > effectivePageSize)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${(_currentPage * effectivePageSize) + 1} to '
                                '${((_currentPage + 1) * effectivePageSize).clamp(1, _filteredStudents.length)} of ${_filteredStudents.length}',
                                style: AppTextStyles.labelXs.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
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
                                    isEnabled:
                                        (_currentPage + 1) * effectivePageSize <
                                        _filteredStudents.length,
                                    onTap: () => setState(() => _currentPage++),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ArmsStickyFooter(
                      primaryButtonText:
                          _isSaving
                              ? 'Saving...'
                              : (keyboardOpen ? 'Next' : 'Save & Close'),
                      onPrimaryPressed:
                          _isSaving
                              ? () {}
                              : () => _handleActionButtonPressed(context),
                    ),
                  ),
                ],
              ),
    );
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
