import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
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

  // General Dropdown States
  String _selectedSeries = 'Mid Term 2024';
  final List<String> _seriesOptions = [
    'Mid Term 2024',
    'Final Exam 2024',
    'Weekly Assessment',
  ];

  String _selectedSchool = 'Greenwood High International';
  final List<String> _schoolOptions = [
    'Greenwood High International',
    'Riverside Public School',
  ];

  String _selectedClass = 'Class 10';
  final List<String> _classOptions = ['Class 10', 'Class 11', 'Class 12'];

  // Subject multi-select states
  final List<String> _availableSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'History',
  ];
  final List<String> _selectedSubjects = ['Mathematics', 'Physics'];

  // Section checkbox states
  final Map<String, bool> _sections = {
    'Section A': true,
    'Section B': false,
    'Section C': false,
  };

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Default today's date formatted
    final now = DateTime.now();
    _dateController.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _marksController.text = "100";
    _nameController.text = "Mathematics Advanced Quiz";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _chapterController.dispose();
    _topicController.dispose();
    _dateController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  void _showSubjectSelectSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      'Select Subjects',
                      style: AppTextStyles.headerSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children:
                            _availableSubjects.map((sub) {
                              final isSelected = _selectedSubjects.contains(
                                sub,
                              );
                              return CheckboxListTile(
                                title: Text(
                                  sub,
                                  style: AppTextStyles.bodyMedium,
                                ),
                                value: isSelected,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      _selectedSubjects.add(sub);
                                    } else {
                                      _selectedSubjects.remove(sub);
                                    }
                                  });
                                  setState(() {}); // Update main screen
                                },
                              );
                            }).toList(),
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

    // Simulate creation spinner (matching standard exam-create micro-interaction)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final List<String> activeSecs = [];
    _sections.forEach((k, v) {
      if (v) activeSecs.add(k);
    });

    final newExam = {
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'name':
          _nameController.text.trim().isEmpty
              ? 'Untitled Exam'
              : _nameController.text.trim(),
      'exam_date': _dateController.text,
      'total_marks': int.tryParse(_marksController.text) ?? 100,
      'mark_saved': false,
      'topic':
          _topicController.text.trim().isEmpty
              ? 'General Syllabus'
              : _topicController.text.trim(),
      'series': {
        'id': 'series_${_selectedSeries.hashCode}',
        'name': _selectedSeries,
        'code': _selectedSeries.substring(0, 3).toUpperCase(),
      },
      'subjects':
          _selectedSubjects
              .map(
                (s) => {
                  'id': 'sub_${s.toLowerCase()}',
                  'subject': {
                    'id': 'sub_${s.toLowerCase()}',
                    'name': s,
                    'code': s.substring(0, 3).toUpperCase(),
                  },
                  'max_marks': int.tryParse(_marksController.text) ?? 100,
                },
              )
              .toList(),
      'for_school': '["$_selectedSchool"]',
      'for_class': '["$_selectedClass"]',
      'for_section':
          activeSecs.isEmpty
              ? '["Section A"]'
              : '["${activeSecs.join("\", \"")}"]',
    };

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

    Navigator.of(context).pop(newExam);
  }

  @override
  Widget build(BuildContext context) {
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
                  value: _selectedSeries,
                  onTap:
                      () => _showSingleSelectSheet(
                        title: 'Select Exam Series',
                        currentValue: _selectedSeries,
                        options: _seriesOptions,
                        onSelected: (val) {
                          setState(() => _selectedSeries = val);
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
                                  sub,
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap:
                                      () => setState(
                                        () => _selectedSubjects.remove(sub),
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
                ArmsInputField(
                  controller: _marksController,
                  hintText: '100',
                  keyboardType: TextInputType.number,
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
                  label: 'Select Schools',
                  value: _selectedSchool,
                  onTap:
                      () => _showSingleSelectSheet(
                        title: 'Select Schools',
                        currentValue: _selectedSchool,
                        options: _schoolOptions,
                        onSelected: (val) {
                          setState(() => _selectedSchool = val);
                        },
                      ),
                ),
                const SizedBox(height: 16),
                // Classes dropdown
                ArmsDropdownSelector(
                  label: 'Select Class',
                  value: _selectedClass,
                  onTap:
                      () => _showSingleSelectSheet(
                        title: 'Select Class',
                        currentValue: _selectedClass,
                        options: _classOptions,
                        onSelected: (val) {
                          setState(() => _selectedClass = val);
                        },
                      ),
                ),
                const SizedBox(height: 16),
                // Sections checkbox row list
                _buildLabel('Select Sections'),
                Row(
                  children:
                      _sections.keys.map((secName) {
                        final isChecked = _sections[secName] == true;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _sections[secName] = !isChecked;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
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
                              child: Center(
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
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          // Auto-saved summary
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.drafts_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-saved at 10:45 AM',
                style: AppTextStyles.labelXs.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Save as Draft button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.outlineMedium),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.roundFull),
                ),
              ),
              child: Text(
                'Save as Draft',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                      final isSelected = opt == currentValue;
                      return ListTile(
                        title: Text(
                          opt,
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
}
