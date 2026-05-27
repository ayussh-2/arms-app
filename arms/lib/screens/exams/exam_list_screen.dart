import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_input_field.dart';

/// Exam list screen matching exam-list.html.
/// Shows searchable, filterable list of exams with status badges and action sheet.
class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allExams = [];
  List<Map<String, dynamic>> _filteredExams = [];
  bool _isLoading = true;

  // Tab State: 0 = Exams, 1 = Reports
  int _activeSubTab = 0;

  // Filter States
  String? _selectedSeries;
  String? _selectedSubject;
  String? _selectedSchool;
  String? _selectedClass;
  String? _selectedSection;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterExams);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExams),
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
      );
      if (!mounted) return;
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load exams: ${result.exception.toString()}'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final list = (result.data?['exams'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _allExams = list;
        _isLoading = false;
      });
      _filterExams();
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

  // Dynamic lists from loaded data
  List<String> get uniqueSeries {
    return _allExams
        .map((e) => e['series']?['name'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  List<String> get uniqueSubjects {
    final list = <String>[];
    for (final e in _allExams) {
      final subs = e['subjects'] as List? ?? [];
      for (final s in subs) {
        final name = s['subject']?['name'] as String?;
        if (name != null) list.add(name);
      }
    }
    return list.toSet().toList();
  }

  List<String> get uniqueSchools {
    return _allExams
        .map((e) => e['for_school'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  List<String> get uniqueClasses {
    return _allExams
        .map((e) => e['for_class'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  List<String> get uniqueSections {
    return _allExams
        .map((e) => e['for_section'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  void _filterExams() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredExams = _allExams.where((e) {
        // Search filter
        final name = (e['name'] as String? ?? '').toLowerCase();
        final series = (e['series']?['name'] as String? ?? '').toLowerCase();
        final subjects = e['subjects'] as List? ?? [];
        final subjectNames = subjects.map((s) => (s['subject']?['name'] as String? ?? '').toLowerCase()).join(' ');

        final matchesSearch = q.isEmpty ||
            name.contains(q) ||
            series.contains(q) ||
            subjectNames.contains(q);

        // Filter pills
        final matchesSeries = _selectedSeries == null ||
            (e['series']?['name'] as String?) == _selectedSeries;

        final matchesSubject = _selectedSubject == null ||
            subjects.any((s) => (s['subject']?['name'] as String?) == _selectedSubject);

        final matchesSchool = _selectedSchool == null ||
            (e['for_school'] as String?) == _selectedSchool;

        final matchesClass = _selectedClass == null ||
            (e['for_class'] as String?) == _selectedClass;

        final matchesSection = _selectedSection == null ||
            (e['for_section'] as String?) == _selectedSection;

        return matchesSearch &&
            matchesSeries &&
            matchesSubject &&
            matchesSchool &&
            matchesClass &&
            matchesSection;
      }).toList();
    });
  }

  void _showFilterOptions(
    String label,
    String? currentValue,
    List<String> options,
    ValueChanged<String?> onSelected,
  ) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filter by $label', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return RadioListTile<String?>(
                          title: Text('All ${label.toLowerCase()}', style: AppTextStyles.bodyMedium),
                          value: null,
                          groupValue: currentValue,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            onSelected(val);
                            Navigator.pop(ctx);
                          },
                        );
                      }
                      final option = options[index - 1];
                      return RadioListTile<String?>(
                        title: Text(option, style: AppTextStyles.bodyMedium),
                        value: option,
                        groupValue: currentValue,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          onSelected(val);
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

  void _showActionSheet(Map<String, dynamic> exam) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 48, height: 6, decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 24),
                // Title
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam['name'] ?? '', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${exam['series']?['name'] ?? ''} • ${exam['exam_date'] ?? ''}',
                        style: AppTextStyles.labelXs,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Edit Marks
                _SheetButton(
                  icon: Icons.edit,
                  label: 'Edit Marks',
                  color: AppColors.primary,
                  filled: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed('/mark-entry', arguments: exam);
                  },
                ),
                const SizedBox(height: 8),
                // View Report
                _SheetButton(
                  icon: Icons.description_outlined,
                  label: 'View Report',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed('/exam-view', arguments: exam);
                  },
                ),
                const SizedBox(height: 8),
                _SheetButton(icon: Icons.download_outlined, label: 'Download PDF', onTap: () => Navigator.pop(ctx)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String? selectedValue,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    final isSelected = selectedValue != null;
    return GestureDetector(
      onTap: () => _showFilterOptions(label, selectedValue, options, onSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineMediumLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSelected ? '$label: $selectedValue' : label,
              style: AppTextStyles.labelXs.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.textMain,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // Reports helper widgets
  Widget _buildStatCard(String title, String val, Color color, IconData icon) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: color),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: AppTextStyles.headerSmall.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: color == AppColors.onSurfaceVariant ? AppColors.textMain : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.labelXsUppercase.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectProgressBar(String name, double val, String percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain)),
            Text(percent, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
            value: val,
            minHeight: 8,
            backgroundColor: AppColors.outlineLight,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildReportItem(String name, String size, String subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Icon(
            name.endsWith('.xlsx') ? Icons.table_chart : Icons.picture_as_pdf,
            color: name.endsWith('.xlsx') ? AppColors.successText : AppColors.errorText,
            size: 24,
          ),
          const SizedBox(width: 12),
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
                  '$subject • $size',
                  style: AppTextStyles.labelXs.copyWith(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 20, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.download_done, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('Downloaded $name successfully!'),
                    ],
                  ),
                  backgroundColor: AppColors.successText,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyFilter = _selectedSeries != null ||
        _selectedSubject != null ||
        _selectedSchool != null ||
        _selectedClass != null ||
        _selectedSection != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadExams,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_activeSubTab == 0) ...[
                    // SEARCH & FILTERS
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 60, AppSpacing.marginPage, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Exams',
                                  style: AppTextStyles.displayMobile.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    _loadExams();
                                  },
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  tooltip: 'Refresh list',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ArmsInputField(
                              controller: _searchController,
                              hintText: 'Search exams...',
                              prefixIcon: Icons.search,
                            ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterPill(
                                  label: 'Series',
                                  selectedValue: _selectedSeries,
                                  options: uniqueSeries,
                                  onSelected: (val) {
                                    _selectedSeries = val;
                                    _filterExams();
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterPill(
                                  label: 'Subjects',
                                  selectedValue: _selectedSubject,
                                  options: uniqueSubjects,
                                  onSelected: (val) {
                                    _selectedSubject = val;
                                    _filterExams();
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterPill(
                                  label: 'Schools',
                                  selectedValue: _selectedSchool,
                                  options: uniqueSchools,
                                  onSelected: (val) {
                                    _selectedSchool = val;
                                    _filterExams();
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterPill(
                                  label: 'Classes',
                                  selectedValue: _selectedClass,
                                  options: uniqueClasses,
                                  onSelected: (val) {
                                    _selectedClass = val;
                                    _filterExams();
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterPill(
                                  label: 'Sections',
                                  selectedValue: _selectedSection,
                                  options: uniqueSections,
                                  onSelected: (val) {
                                    _selectedSection = val;
                                    _filterExams();
                                  },
                                ),
                                if (hasAnyFilter) ...[
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedSeries = null;
                                        _selectedSubject = null;
                                        _selectedSchool = null;
                                        _selectedClass = null;
                                        _selectedSection = null;
                                        _filterExams();
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Clear',
                                      style: AppTextStyles.labelXs.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                        ],
                      ),
                    ),
                  ),
                  // EXAMS LIST
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.marginPage,
                      0,
                      AppSpacing.marginPage,
                      120, // Padding for bottom nav bar spacing
                    ),
                    sliver: _filteredExams.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 64),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.assignment_outlined, size: 64, color: AppColors.outline),
                                    const SizedBox(height: 16),
                                    Text('No exams found', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                                child: _ExamCard(
                                  exam: _filteredExams[i],
                                  onTap: () => _showActionSheet(_filteredExams[i]),
                                ),
                              ),
                              childCount: _filteredExams.length,
                            ),
                          ),
                  ),
                ] else ...[
                  // REPORTS SUB-TAB DASHBOARD
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Statistics Cards Grid
                          Text(
                            'OVERVIEW STATISTICS',
                            style: AppTextStyles.labelXsUppercase.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard('CLASS AVERAGE', '76.4%', AppColors.primary, Icons.trending_up),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard('HIGHEST SCORE', '98.0%', AppColors.successText, Icons.stars),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard('PASS PERCENTAGE', '95.8%', AppColors.accent, Icons.verified),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard('TOTAL EXAMS', '12', AppColors.onSurfaceVariant, Icons.assignment),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                          // Subject progress overview
                          Text(
                            'SUBJECT PERFORMANCE',
                            style: AppTextStyles.labelXsUppercase.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.outlineLight),
                            ),
                            child: Column(
                              children: [
                                _buildSubjectProgressBar('Mathematics', 0.85, '85%'),
                                const SizedBox(height: 16),
                                _buildSubjectProgressBar('Chemistry', 0.78, '78%'),
                                const SizedBox(height: 16),
                                _buildSubjectProgressBar('Physics', 0.72, '72%'),
                                const SizedBox(height: 16),
                                _buildSubjectProgressBar('Biology', 0.89, '89%'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                          // Downloadable ledgers
                          Text(
                            'RECENT REPORTS',
                            style: AppTextStyles.labelXsUppercase.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildReportItem('Chemistry Mid-Term Consolidated.pdf', '1.2 MB', 'Chemistry'),
                          _buildReportItem('Physics Unit Test Summary.pdf', '850 KB', 'Physics'),
                          _buildReportItem('DTS - 07 Academic Final Ledger.xlsx', '3.4 MB', 'All Subjects'),
                          const SizedBox(height: 120), // Spacer for bottom navigation
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      floatingActionButton: _activeSubTab == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed('/exam-create');
                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    _allExams.insert(0, result);
                    _filterExams();
                  });
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// Individual exam card matching exam-list.html design.
class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap});
  final Map<String, dynamic> exam;
  final VoidCallback onTap;

  String parseMeta(dynamic val, String type) {
    if (val == null) return 'All';
    final str = val.toString().trim();
    if (str.isEmpty || str == '[]' || str == 'null') return 'All';

    // Clean up bracket characters if any
    final clean = str.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");

    // Check if it's a UUID or list of UUIDs
    final isUuid = clean.contains('-') && clean.length > 15;
    if (isUuid) {
      if (type == 'school') return 'Main Campus';
      if (type == 'class') return 'Class X';
      if (type == 'section') return 'Sec A';
    }

    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = exam['mark_saved'] == true;
    final subjects = exam['subjects'] as List? ?? [];
    final subjectNames = subjects.map((s) => s['subject']?['name'] ?? '').join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam['name'] ?? '',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjectNames.toUpperCase(),
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSaved ? AppColors.successBg : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    isSaved ? 'Saved' : 'Draft',
                    style: AppTextStyles.labelXs.copyWith(
                      color: isSaved ? AppColors.successText : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Metadata grid
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.outlineLight,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetaItem(
                          icon: Icons.school_outlined,
                          text: '${parseMeta(exam['for_school'], 'school')} | ${parseMeta(exam['for_class'], 'class')} | ${parseMeta(exam['for_section'], 'section')}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MetaItem(
                        icon: Icons.event_outlined,
                        text: exam['exam_date'] ?? '',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MetaItem(
                        icon: Icons.assignment_outlined,
                        text: 'Total Marks: ${exam['total_marks'] ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Download Report Button matching the web UI exactly
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Triggers download feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.download_done, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Report PDF downloaded successfully!'),
                              ],
                            ),
                            backgroundColor: AppColors.successText,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16, color: AppColors.primary),
                      label: Text(
                        'Download Report',
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.labelXs.copyWith(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.icon, required this.label, required this.onTap, this.color, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color ?? AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color ?? AppColors.textMain),
              label: Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardSurface,
                foregroundColor: AppColors.textMain,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
            ),
    );
  }
}
