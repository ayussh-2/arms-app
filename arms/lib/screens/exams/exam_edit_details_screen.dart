import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_sticky_footer.dart';
import '../../widgets/components/arms_input_field.dart';
import '../../widgets/arms_dropdown_selector.dart';
import '../../widgets/components/arms_date_field.dart';

class ExamEditDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> exam;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> schoolsLookup;
  final List<Map<String, dynamic>> classesLookup;
  final List<Map<String, dynamic>> sectionsLookup;

  const ExamEditDetailsScreen({
    super.key,
    required this.exam,
    required this.subjects,
    required this.schoolsLookup,
    required this.classesLookup,
    required this.sectionsLookup,
  });

  @override
  State<ExamEditDetailsScreen> createState() => _ExamEditDetailsScreenState();
}

class _ExamEditDetailsScreenState extends State<ExamEditDetailsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _chapterCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _marksCtrl;
  late final TextEditingController _dateCtrl;

  late final Set<String> _selectedSchoolIds;
  late final Set<String> _selectedClassIds;
  late final Set<String> _selectedSectionIds;

  final Map<String, TextEditingController> _subjectMarkControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.exam['name'] ?? '');
    _chapterCtrl = TextEditingController(text: widget.exam['chapter'] ?? '');
    _topicCtrl = TextEditingController(text: widget.exam['topic'] ?? '');
    _marksCtrl = TextEditingController(
      text: (widget.exam['total_marks'] ?? 0).toString(),
    );

    final rawDate = widget.exam['exam_date'] as String? ?? '';
    String initialDateStr = '';
    if (rawDate.isNotEmpty) {
      try {
        final parsed = DateTime.parse(rawDate);
        initialDateStr =
            "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
      } catch (_) {
        initialDateStr = rawDate;
      }
    }
    _dateCtrl = TextEditingController(text: initialDateStr);

    _selectedSchoolIds = _mapValuesToIds(
      widget.exam['for_school'] as List?,
      widget.schoolsLookup,
    );
    _selectedClassIds = _mapValuesToIds(
      widget.exam['for_class'] as List?,
      widget.classesLookup,
    );
    _selectedSectionIds = _mapValuesToIds(
      widget.exam['for_section'] as List?,
      widget.sectionsLookup,
    );

    for (final sub in widget.subjects) {
      final subId = sub['id'] as String;
      final maxMarksVal = sub['max_marks'] ?? 100;
      _subjectMarkControllers[subId] = TextEditingController(
        text: maxMarksVal.toString(),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _chapterCtrl.dispose();
    _topicCtrl.dispose();
    _marksCtrl.dispose();
    _dateCtrl.dispose();
    for (final ctrl in _subjectMarkControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Set<String> _mapValuesToIds(List? values, List<Map<String, dynamic>> lookup) {
    final Set<String> ids = {};
    if (values == null) return ids;
    for (final val in values) {
      final valStr = val.toString().trim();
      if (valStr.isEmpty) continue;

      final matchById = lookup.any((item) => item['id']?.toString() == valStr);
      if (matchById) {
        ids.add(valStr);
        continue;
      }

      final matchByName = lookup.firstWhere(
        (item) =>
            item['name']?.toString().toLowerCase() == valStr.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (matchByName.isNotEmpty && matchByName['id'] != null) {
        ids.add(matchByName['id'].toString());
        continue;
      }

      ids.add(valStr);
    }
    return ids;
  }

  String _getDisplayValue({
    required Set<String> selectedIds,
    required List<Map<String, dynamic>> options,
    required String placeholder,
  }) {
    if (selectedIds.isEmpty) return placeholder;
    if (selectedIds.length == options.length) return 'All';

    final names =
        options
            .where((opt) => selectedIds.contains(opt['id']?.toString()))
            .map((opt) => opt['name'] as String? ?? '')
            .toList();

    if (names.isEmpty) return placeholder;
    if (names.length <= 3) {
      return names.join(', ');
    }
    return 'Selected (${names.length})';
  }

  void _showMultiSelectSheet({
    required String title,
    required List<Map<String, dynamic>> options,
    required Set<String> selectedIds,
    required VoidCallback onSelectionChanged,
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
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.outline.withValues(alpha: 0.3),
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
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: isAllSelected,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            selectedIds.addAll(
                              options.map((e) => e['id'] as String),
                            );
                          } else {
                            selectedIds.clear();
                          }
                        });
                        onSelectionChanged();
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
                              onSelectionChanged();
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

  void _updateCalculatedTotalMarks() {
    int total = 0;
    for (final sub in widget.subjects) {
      final subId = sub['id'] as String;
      final val =
          int.tryParse(_subjectMarkControllers[subId]?.text.trim() ?? '0') ?? 0;
      total += val;
    }
    _marksCtrl.text = total.toString();
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
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

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSingleMarks = widget.subjects.length <= 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        title: 'Edit Exam Details',
        showBackButton: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('EXAM NAME'),
                  ArmsInputField(
                    controller: _nameCtrl,
                    hintText: 'Enter Exam Name',
                  ),
                  _buildLabel('CHAPTER'),
                  ArmsInputField(
                    controller: _chapterCtrl,
                    hintText: 'e.g., Chapter 04',
                  ),
                  _buildLabel('TOPIC'),
                  ArmsInputField(
                    controller: _topicCtrl,
                    hintText: 'e.g., Calculus',
                  ),
                  _buildLabel('EXAM DATE'),
                  ArmsDateField(
                    controller: _dateCtrl,
                    hintText: 'YYYY-MM-DD',
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _parseDate(_dateCtrl.text),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _dateCtrl.text =
                              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        });
                      }
                    },
                  ),
                  _buildLabel('ASSIGN TO SCHOOLS'),
                  ArmsDropdownSelector(
                    value: _getDisplayValue(
                      selectedIds: _selectedSchoolIds,
                      options: widget.schoolsLookup,
                      placeholder: 'Select Schools',
                    ),
                    onTap:
                        () => _showMultiSelectSheet(
                          title: 'Select Schools',
                          options: widget.schoolsLookup,
                          selectedIds: _selectedSchoolIds,
                          onSelectionChanged: () => setState(() {}),
                        ),
                  ),
                  _buildLabel('ASSIGN TO CLASSES'),
                  ArmsDropdownSelector(
                    value: _getDisplayValue(
                      selectedIds: _selectedClassIds,
                      options: widget.classesLookup,
                      placeholder: 'Select Classes',
                    ),
                    onTap:
                        () => _showMultiSelectSheet(
                          title: 'Select Classes',
                          options: widget.classesLookup,
                          selectedIds: _selectedClassIds,
                          onSelectionChanged: () => setState(() {}),
                        ),
                  ),
                  _buildLabel('ASSIGN TO SECTIONS'),
                  ArmsDropdownSelector(
                    value: _getDisplayValue(
                      selectedIds: _selectedSectionIds,
                      options: widget.sectionsLookup,
                      placeholder: 'Select Sections',
                    ),
                    onTap:
                        () => _showMultiSelectSheet(
                          title: 'Select Sections',
                          options: widget.sectionsLookup,
                          selectedIds: _selectedSectionIds,
                          onSelectionChanged: () => setState(() {}),
                        ),
                  ),
                  if (isSingleMarks) ...[
                    _buildLabel('TOTAL MARKS'),
                    ArmsInputField(
                      controller: _marksCtrl,
                      hintText: 'Enter Total Marks',
                      keyboardType: TextInputType.number,
                    ),
                  ] else ...[
                    _buildLabel('ALLOCATE SUBJECT MARKS'),
                    Column(
                      children:
                          widget.subjects.map((sub) {
                            final subId = sub['id'] as String;
                            final controller =
                                _subjectMarkControllers[subId]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      sub['name'] ?? '',
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(
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
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: AppColors.outline
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            _updateCalculatedTotalMarks();
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                    _buildLabel('TOTAL MARKS'),
                    AbsorbPointer(
                      child: ArmsInputField(
                        controller: _marksCtrl,
                        hintText: 'Total Marks (Auto-calculated)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ArmsStickyFooter(
              primaryButtonText: _isSaving ? 'Saving...' : 'Save Changes',
              onPrimaryPressed: _isSaving ? () {} : _handleSave,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    final messenger = ScaffoldMessenger.of(context);
    final newName = _nameCtrl.text.trim();
    final newChapter = _chapterCtrl.text.trim();
    final newTopic = _topicCtrl.text.trim();
    final newMarks = int.tryParse(_marksCtrl.text.trim()) ?? 0;
    final newDate = _dateCtrl.text.trim();

    if (newName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Exam name cannot be empty'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final List<String> subjectIds = [];
    final Map<String, int> subjectMarksMap = {};

    final isSingleMarks = widget.subjects.length <= 1;
    if (isSingleMarks) {
      if (widget.subjects.isNotEmpty) {
        final singleSubId = widget.subjects.first['id'] as String;
        subjectIds.add(singleSubId);
        subjectMarksMap[singleSubId] = newMarks;
      }
    } else {
      for (final sub in widget.subjects) {
        final subId = sub['id'] as String;
        subjectIds.add(subId);
        final markText = _subjectMarkControllers[subId]?.text.trim() ?? '100';
        final markVal = int.tryParse(markText) ?? 100;
        subjectMarksMap[subId] = markVal;
      }
    }

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(
        MutationOptions(
          document: gql(GqlQueries.updateExamSetup),
          variables: {
            'examId': widget.exam['id'],
            'input': {
              'name': newName,
              'chapter': newChapter.isEmpty ? 'General' : newChapter,
              'topic': newTopic.isEmpty ? 'General Syllabus' : newTopic,
              'exam_date': newDate,
              'for_school': _selectedSchoolIds.toList(),
              'for_class': _selectedClassIds.toList(),
              'for_section': _selectedSectionIds.toList(),
              'total_marks': newMarks,
              'subject_ids': subjectIds,
              'subject_marks': jsonEncode(subjectMarksMap),
            },
          },
        ),
      );

      if (result.hasException) {
        throw result.exception!;
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Exam details updated successfully'),
            backgroundColor: AppColors.successText,
          ),
        );
        Navigator.pop(context, {
          'name': newName,
          'chapter': newChapter,
          'topic': newTopic,
          'exam_date': newDate,
          'for_school': _selectedSchoolIds.toList(),
          'for_class': _selectedClassIds.toList(),
          'for_section': _selectedSectionIds.toList(),
          'total_marks': newMarks,
          'subject_marks': subjectMarksMap,
        });
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update details on server: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
