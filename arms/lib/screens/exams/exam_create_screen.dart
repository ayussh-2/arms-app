import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import 'widgets/exam_create_general_info.dart';
import 'widgets/assign_students_section.dart';
import 'widgets/exam_selection_sheets.dart';

/// Exam creation screen matching the exam-create.html design.
/// Allows administrators to set up new exam papers, assign subjects, chapters, dates, and student sections.
class ExamCreateScreen extends StatefulWidget {
  const ExamCreateScreen({super.key});

  @override
  State<ExamCreateScreen> createState() => _ExamCreateScreenState();
}

class _ExamCreateScreenState extends State<ExamCreateScreen> {
  // Text Controllers
  final _nameController = TextEditingController();
  final _chapterController = TextEditingController();
  final _topicController = TextEditingController();
  final _dateController = TextEditingController();
  final _marksController = TextEditingController();

  // GraphQL & Lookups State
  bool _isLoadingLookups = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _schoolsLookup = [];
  List<Map<String, dynamic>> _classesLookup = [];
  List<Map<String, dynamic>> _sectionsLookup = [];
  List<Map<String, dynamic>> _seriesLookup = [];
  List<Map<String, dynamic>> _subjectsLookup = [];

  // Selections
  Map<String, dynamic>? _selectedSeries;
  final Set<String> _selectedSchoolIds = {};
  final Set<String> _selectedClassIds = {};
  final List<Map<String, dynamic>> _selectedSubjects = [];
  final Set<String> _selectedSectionIds = {};

  // Subject marks controllers
  final Map<String, TextEditingController> _subjectMarkControllers = {};

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _marksController.text = "0";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoadingLookups) {
      _loadLookups();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _chapterController.dispose();
    _topicController.dispose();
    _dateController.dispose();
    _marksController.dispose();
    for (final ctrl in _subjectMarkControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() {
          _isLoadingLookups = false;
          _errorMessage = 'Organization session expired. Please log in again.';
        });
        return;
      }
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExamLookups),
          variables: {
            'organisationId': orgId,
          },
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        setState(() {
          _isLoadingLookups = false;
          _errorMessage = 'Failed to load options from the server.';
        });
        return;
      }

      final lookups = result.data?['getExamLookups'];
      if (lookups != null) {
        setState(() {
          _schoolsLookup = (lookups['schools'] as List? ?? []).cast<Map<String, dynamic>>();
          _classesLookup = (lookups['classes'] as List? ?? []).cast<Map<String, dynamic>>();
          _sectionsLookup = (lookups['sections'] as List? ?? []).cast<Map<String, dynamic>>();
          _seriesLookup = (lookups['series'] as List? ?? []).cast<Map<String, dynamic>>();
          _subjectsLookup = (lookups['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

          if (_seriesLookup.isNotEmpty) {
            _selectedSeries = _seriesLookup.first;
            _autoSelectAndRecommendSubjects();
          }
          
          _selectedSchoolIds.addAll(_schoolsLookup.map((e) => e['id'] as String));
          _selectedClassIds.addAll(_classesLookup.map((e) => e['id'] as String));
          _selectedSectionIds.addAll(_sectionsLookup.map((e) => e['id'] as String));
          
          _isLoadingLookups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLookups = false;
          _errorMessage = 'An error occurred while fetching options.';
        });
      }
    }
  }

  void _autoSelectAndRecommendSubjects() {
    final List<dynamic> rawIds = _selectedSeries?['subject_ids'] ?? [];
    final Set<String> seriesSubjectIds = rawIds.map((id) => id.toString()).toSet();

    _selectedSubjects.clear();

    for (final ctrl in _subjectMarkControllers.values) {
      ctrl.dispose();
    }
    _subjectMarkControllers.clear();

    for (final subId in seriesSubjectIds) {
      final sub = _subjectsLookup.firstWhere(
        (s) => s['id'] == subId,
        orElse: () => <String, dynamic>{},
      );
      if (sub.isNotEmpty) {
        _selectedSubjects.add(sub);
        _subjectMarkControllers[subId] = TextEditingController(text: '100');
      }
    }

    _updateTotalMarks();
  }

  void _updateTotalMarks() {
    int total = 0;
    for (final sub in _selectedSubjects) {
      final subId = sub['id'] as String;
      final text = _subjectMarkControllers[subId]?.text.trim() ?? '100';
      total += int.tryParse(text) ?? 100;
    }
    setState(() {
      _marksController.text = total.toString();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter an exam name.');
      return;
    }
    if (_selectedSeries == null) {
      _showError('Please select an exam series.');
      return;
    }
    if (_selectedSubjects.isEmpty) {
      _showError('Please select at least one subject.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      final adminId = AuthService.currentAdmin?.id;
      if (orgId == null || adminId == null) {
        throw 'Admin session is expired. Please log in again.';
      }

      final client = GraphQLProvider.of(context).value;
      final List<String> subjectIds = [];
      final Map<String, int> subjectMarksMap = {};

      for (final sub in _selectedSubjects) {
        final subId = sub['id'] as String;
        subjectIds.add(subId);
        final markText = _subjectMarkControllers[subId]?.text.trim() ?? '100';
        subjectMarksMap[subId] = int.tryParse(markText) ?? 100;
      }

      final subjectMarksJson = jsonEncode(subjectMarksMap);
      final totalMarks = subjectMarksMap.values.fold<int>(0, (sum, val) => sum + val);

      final input = {
        'organisation_id': orgId,
        'series_id': _selectedSeries!['id'] as String,
        'name': name,
        'chapter': _chapterController.text.trim().isEmpty ? 'General' : _chapterController.text.trim(),
        'topic': _topicController.text.trim().isEmpty ? 'General Syllabus' : _topicController.text.trim(),
        'exam_date': _dateController.text.trim(),
        'total_marks': totalMarks,
        'for_school': _selectedSchoolIds.toList(),
        'for_class': _selectedClassIds.toList(),
        'for_section': _selectedSectionIds.toList(),
        'created_by': adminId,
        'subject_ids': subjectIds,
        'subject_marks': subjectMarksJson,
      };

      final result = await client.mutate(
        MutationOptions(
          document: gql(GqlQueries.createExam),
          variables: {'input': input},
        ),
      );

      if (result.hasException) throw result.exception!;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Exam Created Successfully!'),
            ],
          ),
          backgroundColor: AppColors.successText,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError('Failed to create exam: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLookups) {
      return const Scaffold(
        backgroundColor: Colors.white,
        appBar: ArmsTopAppBar(title: 'Create Exam', showBackButton: true),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: const ArmsTopAppBar(title: 'Create Exam', showBackButton: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.errorText),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadLookups,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const ArmsTopAppBar(title: 'Create Exam', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginPage,
          AppSpacing.stackMd,
          AppSpacing.marginPage,
          AppSpacing.marginPage,
        ),
        children: [
          ExamCreateGeneralInfo(
            nameController: _nameController,
            chapterController: _chapterController,
            topicController: _topicController,
            dateController: _dateController,
            marksController: _marksController,
            selectDate: _selectDate,
            showSeriesSelector: () => showExamSingleSelectSheet(
              context: context,
              title: 'Select Exam Series',
              currentValue: _selectedSeries,
              options: _seriesLookup,
              onSelected: (val) {
                setState(() {
                  _selectedSeries = val;
                  _autoSelectAndRecommendSubjects();
                });
              },
            ),
            selectedSeriesName: _selectedSeries?['name'] as String?,
            showSubjectSelectSheet: () => showSubjectSelectSheet(
              context: context,
              subjectsLookup: _subjectsLookup,
              selectedSubjects: _selectedSubjects,
              subjectMarkControllers: _subjectMarkControllers,
              onSelectionChanged: _updateTotalMarks,
            ),
            selectedSubjects: _selectedSubjects,
            subjectControllers: _subjectMarkControllers,
            onSubjectRemoved: (sub) {
              setState(() {
                _selectedSubjects.remove(sub);
                _updateTotalMarks();
              });
            },
            onSubjectMarkChanged: _updateTotalMarks,
          ),
          const SizedBox(height: AppSpacing.stackLg),
          AssignStudentsSection(
            schoolsLookup: _schoolsLookup,
            classesLookup: _classesLookup,
            sectionsLookup: _sectionsLookup,
            selectedSchoolIds: _selectedSchoolIds,
            selectedClassIds: _selectedClassIds,
            selectedSectionIds: _selectedSectionIds,
            onSelectionChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isCreating ? () {} : _handleCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isCreating ? 'Creating...' : 'Create Exam',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
