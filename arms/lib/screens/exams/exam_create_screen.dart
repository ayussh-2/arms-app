import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../core/utils/logger.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_input_field.dart';
import '../../widgets/arms_dropdown_selector.dart';

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
    // Default today's date formatted
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
        armsLog('Failed to load exam lookups: ${result.exception.toString()}');
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

          // Set default selections if available
          if (_seriesLookup.isNotEmpty) {
            _selectedSeries = _seriesLookup.first;
            _autoSelectAndRecommendSubjects();
          }
          
          // Select "All" by default for schools, classes, and sections
          _selectedSchoolIds.addAll(_schoolsLookup.map((e) => e['id'] as String));
          _selectedClassIds.addAll(_classesLookup.map((e) => e['id'] as String));
          _selectedSectionIds.addAll(_sectionsLookup.map((e) => e['id'] as String));
          
          _isLoadingLookups = false;
        });
      }
    } catch (e) {
      armsLog('Error loading exam lookups: $e');
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

    // Clear old selections
    _selectedSubjects.clear();

    // Clean up and clear old controllers
    for (final ctrl in _subjectMarkControllers.values) {
      ctrl.dispose();
    }
    _subjectMarkControllers.clear();

    // Add subjects configured for the selected series
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

  void _showSubjectSelectSheet() {
    String searchPattern = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _subjectsLookup.where((sub) {
              final name = (sub['name'] as String? ?? '').toLowerCase();
              final code = (sub['code'] as String? ?? '').toLowerCase();
              final q = searchPattern.toLowerCase();
              return q.isEmpty || name.contains(q) || code.contains(q);
            }).toList();

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
                          color: AppColors.outline.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Subjects',
                      style: AppTextStyles.headerSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search subjects...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchPattern = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final sub = filtered[index];
                          final subId = sub['id'] as String;
                          final isSelected = _selectedSubjects.any((s) => s['id'] == subId);

                          return ListTile(
                            title: Text(
                              sub['name'] ?? '',
                              style: AppTextStyles.bodyMedium,
                            ),
                            subtitle: sub['code'] != null 
                                ? Text(sub['code'] as String, style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary)) 
                                : null,
                            leading: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    if (!isSelected) {
                                      _selectedSubjects.add(sub);
                                      if (!_subjectMarkControllers.containsKey(subId)) {
                                        _subjectMarkControllers[subId] = TextEditingController(text: '100');
                                      }
                                    }
                                  } else {
                                    _selectedSubjects.removeWhere((s) => s['id'] == subId);
                                  }
                                  _updateTotalMarks();
                                });
                                setState(() {}); // Update main screen
                              },
                            ),
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
      },
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an exam name.'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    if (_selectedSeries == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an exam series.'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one subject.'),
          backgroundColor: AppColors.errorText,
        ),
      );
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
        final markVal = int.tryParse(markText) ?? 100;
        subjectMarksMap[subId] = markVal;
      }

      final subjectMarksJson = jsonEncode(subjectMarksMap);
      final totalMarks = subjectMarksMap.values.fold<int>(0, (sum, val) => sum + val);

      final List<String> schools = _selectedSchoolIds.toList();
      final List<String> classes = _selectedClassIds.toList();
      final List<String> sections = _selectedSectionIds.toList();

      final input = {
        'organisation_id': orgId,
        'series_id': _selectedSeries!['id'] as String,
        'name': name,
        'chapter': _chapterController.text.trim().isEmpty ? 'General' : _chapterController.text.trim(),
        'topic': _topicController.text.trim().isEmpty ? 'General Syllabus' : _topicController.text.trim(),
        'exam_date': _dateController.text.trim(),
        'total_marks': totalMarks,
        'for_school': schools,
        'for_class': classes,
        'for_section': sections,
        'created_by': adminId,
        'subject_ids': subjectIds,
        'subject_marks': subjectMarksJson,
      };

      final result = await client.mutate(
        MutationOptions(
          document: gql(GqlQueries.createExam),
          variables: {
            'input': input,
          },
        ),
      );

      if (result.hasException) {
        throw result.exception!;
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create exam: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  String _getDisplayValue({
    required Set<String> selectedIds,
    required List<Map<String, dynamic>> options,
    required String placeholder,
  }) {
    if (selectedIds.isEmpty) return placeholder;
    if (selectedIds.length == options.length) return 'All';
    
    final names = options
        .where((opt) => selectedIds.contains(opt['id']))
        .map((opt) => opt['name'] as String? ?? '')
        .toList();
        
    if (names.length <= 3) {
      return names.join(', ');
    }
    return 'Selected (${names.length})';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLookups) {
      return const Scaffold(
        backgroundColor: Colors.white,
        appBar: ArmsTopAppBar(title: 'Create Exam', showBackButton: true),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
          // General Information Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General Information',
                  style: AppTextStyles.headerSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                // Exam Series Selection
                ArmsDropdownSelector(
                  label: 'Select Exam Series',
                  value: _selectedSeries?['name'] as String?,
                  placeholder: 'Select Exam Series',
                  onTap:
                      () => _showSingleSelectSheet(
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
                ),
                const SizedBox(height: 16),
                // Select Subjects Chips Roster
                _buildLabel('Select Subjects'),
                GestureDetector(
                  onTap: _showSubjectSelectSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(
                        AppRadius.roundEight,
                      ),
                      border: Border.all(
                        color: AppColors.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedSubjects.isEmpty
                                ? 'Search and select subjects...'
                                : 'Selected (${_selectedSubjects.length} subjects)',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color:
                                  _selectedSubjects.isEmpty
                                      ? AppColors.textSecondary
                                      : AppColors.textMain,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedSubjects.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _selectedSubjects.map((sub) {
                          final name = sub['name'] as String? ?? '';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(
                                AppRadius.roundFull,
                              ),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap:
                                      () => setState(
                                        () {
                                          _selectedSubjects.remove(sub);
                                          _updateTotalMarks();
                                        },
                                      ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Allocate Subject Marks',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: _selectedSubjects.map((sub) {
                        final subId = sub['id'] as String;
                        final controller = _subjectMarkControllers[subId]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  sub['name'] ?? '',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 44,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    style: AppTextStyles.bodyMedium,
                                    decoration: InputDecoration(
                                      hintText: 'Max Marks',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: AppColors.outline.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.primary),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      _updateTotalMarks();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Exam Name Input
                _buildLabel('Exam Name'),
                ArmsInputField(
                  controller: _nameController,
                  hintText: 'e.g., Mathematics Advanced Quiz',
                ),
                const SizedBox(height: 16),
                // Chapter & Topic
                _buildLabel('Chapter'),
                ArmsInputField(
                  controller: _chapterController,
                  hintText: 'e.g., Chapter 04',
                ),
                const SizedBox(height: 16),
                _buildLabel('Topic'),
                ArmsInputField(
                  controller: _topicController,
                  hintText: 'e.g., Calculus',
                ),
                const SizedBox(height: 16),
                // Exam Date & Total Marks
                _buildLabel('Exam Date'),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: ArmsInputField(
                      controller: _dateController,
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icons.calendar_today,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Total Marks'),
                AbsorbPointer(
                  child: ArmsInputField(
                    controller: _marksController,
                    hintText: 'Total Marks (Auto-calculated)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          // Assign to Students Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign to Students',
                  style: AppTextStyles.headerSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                // Schools dropdown
                ArmsDropdownSelector(
                  label: 'Select School',
                  value: _getDisplayValue(
                    selectedIds: _selectedSchoolIds,
                    options: _schoolsLookup,
                    placeholder: 'Select School',
                  ),
                  onTap:
                      () => _showMultiSelectSheet(
                        title: 'Select School',
                        options: _schoolsLookup,
                        selectedIds: _selectedSchoolIds,
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                ),
                const SizedBox(height: 16),
                // Classes dropdown
                ArmsDropdownSelector(
                  label: 'Select Class',
                  value: _getDisplayValue(
                    selectedIds: _selectedClassIds,
                    options: _classesLookup,
                    placeholder: 'Select Class',
                  ),
                  onTap:
                      () => _showMultiSelectSheet(
                        title: 'Select Class',
                        options: _classesLookup,
                        selectedIds: _selectedClassIds,
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                ),
                const SizedBox(height: 16),
                // Sections checkbox wrap list
                _buildLabel('Select Sections'),
                _sectionsLookup.isEmpty 
                    ? Text('No sections available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Virtual "All" card
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final isAllSelected = _selectedSectionIds.length == _sectionsLookup.length;
                                if (isAllSelected) {
                                  _selectedSectionIds.clear();
                                } else {
                                  _selectedSectionIds.addAll(_sectionsLookup.map((e) => e['id'] as String));
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: (_selectedSectionIds.length == _sectionsLookup.length)
                                        ? AppColors.primary.withOpacity(0.1)
                                        : AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (_selectedSectionIds.length == _sectionsLookup.length)
                                          ? AppColors.primary
                                          : AppColors.outline.withOpacity(0.3),
                                  width: (_selectedSectionIds.length == _sectionsLookup.length) ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                'All',
                                style: AppTextStyles.labelXs.copyWith(
                                  color: (_selectedSectionIds.length == _sectionsLookup.length)
                                          ? AppColors.primary
                                          : AppColors.textMain,
                                  fontWeight: (_selectedSectionIds.length == _sectionsLookup.length)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          ..._sectionsLookup.map((sec) {
                            final secId = sec['id'] as String;
                            final secName = sec['name'] as String? ?? '';
                            final isChecked = _selectedSectionIds.contains(secId);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedSectionIds.remove(secId);
                                  } else {
                                    _selectedSectionIds.add(secId);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isChecked
                                          ? AppColors.primary.withOpacity(0.1)
                                          : AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        isChecked
                                            ? AppColors.primary
                                            : AppColors.outline.withOpacity(
                                              0.3,
                                            ),
                                    width: isChecked ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  secName,
                                  style: AppTextStyles.labelXs.copyWith(
                                    color:
                                        isChecked
                                            ? AppColors.primary
                                            : AppColors.textMain,
                                    fontWeight:
                                        isChecked
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          // Create Exam button
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
                  borderRadius: BorderRadius.circular(AppRadius.roundFull),
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

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showSingleSelectSheet({
    required String title,
    required Map<String, dynamic>? currentValue,
    required List<Map<String, dynamic>> options,
    required ValueChanged<Map<String, dynamic>> onSelected,
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
                Text(
                  title,
                  style: AppTextStyles.headerSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSelected = opt['id'] == currentValue?['id'];
                      return ListTile(
                        title: Text(
                          opt['name'] ?? '',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.textMain,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                )
                                : null,
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

  void _showMultiSelectSheet({
    required String title,
    required List<Map<String, dynamic>> options,
    required Set<String> selectedIds,
    required ValueChanged<Set<String>> onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAllSelected = selectedIds.length == options.length;

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
                          color: AppColors.outline.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: AppTextStyles.headerSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: Text(
                        'All',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      value: isAllSelected,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            selectedIds.addAll(options.map((e) => e['id'] as String));
                          } else {
                            selectedIds.clear();
                          }
                        });
                        onChanged(selectedIds);
                      },
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          final id = opt['id'] as String;
                          final isSelected = selectedIds.contains(id);

                          return CheckboxListTile(
                            title: Text(
                              opt['name'] ?? '',
                              style: AppTextStyles.bodyMedium,
                            ),
                            value: isSelected,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIds.add(id);
                                } else {
                                  selectedIds.remove(id);
                                }
                              });
                              onChanged(selectedIds);
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
      },
    );
  }
}
