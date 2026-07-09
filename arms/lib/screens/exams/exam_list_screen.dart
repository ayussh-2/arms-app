import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/exam_lookup_cache.dart';
import '../../widgets/components/arms_input_field.dart';
import '../../widgets/arms_snackbar.dart';
import 'widgets/exam_filters_panel.dart';
import 'widgets/exam_list_table.dart';
import 'widgets/exam_list_helpers.dart';
import 'widgets/exam_list_sheets.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _allExams = [];
  List<Map<String, dynamic>> _filteredExams = [];
  bool _isLoading = true;

  int _offset = 0;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final int _activeSubTab = 0;

  String? _selectedSeries;
  String? _selectedSubject;
  String? _selectedSchool;
  String? _selectedClass;
  String? _selectedSection;

  List<Map<String, dynamic>> _schoolsLookup = [];
  List<Map<String, dynamic>> _classesLookup = [];
  List<Map<String, dynamic>> _sectionsLookup = [];
  List<Map<String, dynamic>> _seriesLookup = [];
  List<Map<String, dynamic>> _subjectsLookup = [];

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _allExams.isEmpty) {
      _loadLookups();
      _loadExams();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _loadMoreExams();
      }
    }
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _resetAndLoadExams();
    });
  }

  Future<void> _loadLookups() async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) return;
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExamLookups),
          variables: {'organisationId': orgId},
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted || result.hasException) return;

      final lookups = result.data?['getExamLookups'];
      if (lookups != null) {
        setState(() {
          _schoolsLookup = (lookups['schools'] as List? ?? []).cast<Map<String, dynamic>>();
          _classesLookup = (lookups['classes'] as List? ?? []).cast<Map<String, dynamic>>();
          _sectionsLookup = (lookups['sections'] as List? ?? []).cast<Map<String, dynamic>>();
          _seriesLookup = (lookups['series'] as List? ?? []).cast<Map<String, dynamic>>();
          _subjectsLookup = (lookups['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

          ExamLookupCache.updateLookups(
            schoolsList: _schoolsLookup,
            classesList: _classesLookup,
            sectionsList: _sectionsLookup,
            subjectsList: _subjectsLookup,
          );
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic> _buildVariables(int currentOffset) {
    final orgId = AuthService.currentAdmin?.organization?.id;
    final isSearch = _searchController.text.trim().isNotEmpty;
    final hasServerFilters = _selectedSeries != null ||
        _selectedSubject != null ||
        _selectedClass != null ||
        _selectedSchool != null ||
        _selectedSection != null;

    final variables = <String, dynamic>{
      'organisationId': orgId,
      'isDeleted': false,
      'pagination': {'limit': _limit, 'offset': currentOffset},
    };

    if (isSearch) {
      variables['query'] = _searchController.text.trim();
    } else if (hasServerFilters) {
      variables['query'] = '';
    }

    if (hasServerFilters) {
      final filters = <String, dynamic>{};
      if (_selectedSeriesId != null) filters['seriesIds'] = [_selectedSeriesId];
      if (_selectedClassId != null) filters['classIds'] = [_selectedClassId];
      if (_selectedSubjectId != null) filters['subjectIds'] = [_selectedSubjectId];
      if (_selectedSchoolId != null) filters['schoolIds'] = [_selectedSchoolId];
      if (_selectedSectionId != null) filters['sectionIds'] = [_selectedSectionId];
      variables['filters'] = filters;
    }
    return variables;
  }

  Future<void> _resetAndLoadExams({bool forceRefresh = false}) async {
    setState(() {
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
      _allExams.clear();
      _filteredExams.clear();
    });
    await _loadExams(forceRefresh: forceRefresh);
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final client = GraphQLProvider.of(context).value;
      final isSearch = _searchController.text.trim().isNotEmpty;
      final hasServerFilters = _selectedSeries != null ||
          _selectedSubject != null ||
          _selectedClass != null ||
          _selectedSchool != null ||
          _selectedSection != null;

      final queryStr = (isSearch || hasServerFilters) ? GqlQueries.searchExams : GqlQueries.getExamsPaginated;

      final result = await client.query(
        QueryOptions(
          document: gql(queryStr),
          variables: _buildVariables(_offset),
          fetchPolicy: forceRefresh ? FetchPolicy.networkOnly : FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        ArmsSnackbar.showError(context, 'Failed to load exams: ${result.exception.toString()}');
        setState(() => _isLoading = false);
        return;
      }

      final queryKey = (isSearch || hasServerFilters) ? 'searchExams' : 'getExamsPaginated';
      final responseData = result.data?[queryKey];
      final items = (responseData?['items'] as List? ?? []).cast<Map<String, dynamic>>();
      final paginationInfo = responseData?['pagination'] as Map<String, dynamic>?;

      setState(() {
        _allExams = items;
        _hasMore = paginationInfo != null ? (paginationInfo['hasMore'] as bool? ?? false) : (items.length >= _limit);
        _isLoading = false;
      });

      _filterExams();
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Connection error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreExams() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() => _isLoadingMore = false);
        return;
      }
      final nextOffset = _offset + _limit;
      final client = GraphQLProvider.of(context).value;
      final isSearch = _searchController.text.trim().isNotEmpty;
      final hasServerFilters = _selectedSeries != null ||
          _selectedSubject != null ||
          _selectedClass != null ||
          _selectedSchool != null ||
          _selectedSection != null;

      final queryStr = (isSearch || hasServerFilters) ? GqlQueries.searchExams : GqlQueries.getExamsPaginated;

      final result = await client.query(
        QueryOptions(
          document: gql(queryStr),
          variables: _buildVariables(nextOffset),
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        ArmsSnackbar.showError(context, 'Failed to load more exams: ${result.exception.toString()}');
        setState(() => _isLoadingMore = false);
        return;
      }

      final queryKey = (isSearch || hasServerFilters) ? 'searchExams' : 'getExamsPaginated';
      final responseData = result.data?[queryKey];
      final items = (responseData?['items'] as List? ?? []).cast<Map<String, dynamic>>();
      final paginationInfo = responseData?['pagination'] as Map<String, dynamic>?;

      setState(() {
        _offset = nextOffset;
        _allExams.addAll(items);
        _hasMore = paginationInfo != null ? (paginationInfo['hasMore'] as bool? ?? false) : (items.length >= _limit);
        _isLoadingMore = false;
      });

      _filterExams();
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Connection error: $e');
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refreshExams() async {
    _loadLookups();
    await _resetAndLoadExams(forceRefresh: true);
  }

  List<String> get uniqueSeries => _seriesLookup.map((e) => e['name'] as String?).whereType<String>().toList();
  List<String> get uniqueSubjects => _subjectsLookup.map((e) => e['name'] as String?).whereType<String>().toList();
  List<String> get uniqueSchools => _schoolsLookup.map((e) => e['name'] as String?).whereType<String>().toList();
  List<String> get uniqueClasses => _classesLookup.map((e) => e['name'] as String?).whereType<String>().toList();
  List<String> get uniqueSections => _sectionsLookup.map((e) => e['name'] as String?).whereType<String>().toList();

  String? get _selectedSeriesId => _selectedSeries == null ? null : (_seriesLookup.firstWhere((e) => e['name'] == _selectedSeries, orElse: () => <String, dynamic>{})['id'] as String?);
  String? get _selectedSubjectId => _selectedSubject == null ? null : (_subjectsLookup.firstWhere((e) => e['name'] == _selectedSubject, orElse: () => <String, dynamic>{})['id'] as String?);
  String? get _selectedClassId => _selectedClass == null ? null : (_classesLookup.firstWhere((e) => e['name'] == _selectedClass, orElse: () => <String, dynamic>{})['id'] as String?);
  String? get _selectedSchoolId => _selectedSchool == null ? null : (_schoolsLookup.firstWhere((e) => e['name'] == _selectedSchool, orElse: () => <String, dynamic>{})['id'] as String?);
  String? get _selectedSectionId => _selectedSection == null ? null : (_sectionsLookup.firstWhere((e) => e['name'] == _selectedSection, orElse: () => <String, dynamic>{})['id'] as String?);

  void _filterExams() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredExams = _allExams.where((e) {
        final name = (e['name'] as String? ?? '').toLowerCase();
        final series = (e['series']?['name'] as String? ?? '').toLowerCase();
        final subjects = e['subjects'] as List? ?? [];
        final subjectNames = subjects.map((s) => (s['name'] as String? ?? '').toLowerCase()).join(' ');

        return q.isEmpty || name.contains(q) || series.contains(q) || subjectNames.contains(q);
      }).toList();
    });

    if (_filteredExams.isEmpty && _hasMore && !_isLoadingMore && !_isLoading && _activeSubTab == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMoreExams();
      });
    }
  }



  void _showDownloadReportDrawer(Map<String, dynamic> exam) {
    showDownloadReportDrawer(context: context, exam: exam);
  }

  void _showActionSheet(Map<String, dynamic> exam) {
    showActionSheet(
      context: context,
      exam: exam,
      onEditMarks: () {
        Navigator.pop(context);
        Navigator.of(context).pushNamed('/mark-entry', arguments: exam);
      },
      onViewReport: () {
        Navigator.pop(context);
        Navigator.of(context).pushNamed('/exam-view', arguments: exam);
      },
      onDownloadPdf: () {
        Navigator.pop(context);
        _showDownloadReportDrawer(exam);
      },
    );
  }

// _buildFilterPill method removed in favor of ExamFiltersPanel widget.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _activeSubTab == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 60, AppSpacing.marginPage, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Exams', style: AppTextStyles.displayMobile.copyWith(fontWeight: FontWeight.w800, color: AppColors.textMain)),
                          IconButton(
                            onPressed: _refreshExams,
                            icon: const Icon(Icons.refresh, color: AppColors.primary, size: 24),
                            tooltip: 'Refresh list',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ArmsInputField(controller: _searchController, hintText: 'Search exams...', prefixIcon: Icons.search),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ExamFiltersPanel(
                selectedSeries: _selectedSeries,
                selectedSubject: _selectedSubject,
                selectedSchool: _selectedSchool,
                selectedClass: _selectedClass,
                selectedSection: _selectedSection,
                seriesOptions: uniqueSeries,
                subjectOptions: uniqueSubjects,
                schoolOptions: uniqueSchools,
                classOptions: uniqueClasses,
                sectionOptions: uniqueSections,
                onSeriesSelected: (val) {
                  setState(() => _selectedSeries = val);
                  _resetAndLoadExams();
                },
                onSubjectSelected: (val) {
                  setState(() => _selectedSubject = val);
                  _resetAndLoadExams();
                },
                onSchoolSelected: (val) {
                  setState(() => _selectedSchool = val);
                  _resetAndLoadExams();
                },
                onClassSelected: (val) {
                  setState(() => _selectedClass = val);
                  _resetAndLoadExams();
                },
                onSectionSelected: (val) {
                  setState(() => _selectedSection = val);
                  _resetAndLoadExams();
                },
                onClearFilters: () {
                  setState(() {
                    _selectedSeries = null;
                    _selectedSubject = null;
                    _selectedSchool = null;
                    _selectedClass = null;
                    _selectedSection = null;
                  });
                  _resetAndLoadExams();
                },
              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading && _allExams.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _refreshExams,
                          child: _filteredExams.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Padding(
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
                                  ],
                                )
                              : ExamListTable(
                exams: _filteredExams,
                isLoadingMore: _isLoadingMore,
                scrollController: _scrollController,
                onLoadMore: _loadMoreExams,
                onTap: (exam) => _showActionSheet(exam),
                onDownloadReport: (exam) => _showDownloadReportDrawer(exam),
              ),
                        ),
                ),
              ],
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refreshExams,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('OVERVIEW STATISTICS', style: AppTextStyles.labelXsUppercase.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: StatCard(title: 'CLASS AVERAGE', val: '76.4%', color: AppColors.primary, icon: Icons.trending_up)),
                              const SizedBox(width: 12),
                              Expanded(child: StatCard(title: 'HIGHEST SCORE', val: '98.0%', color: AppColors.successText, icon: Icons.stars)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: StatCard(title: 'PASS PERCENTAGE', val: '95.8%', color: AppColors.accent, icon: Icons.verified)),
                              const SizedBox(width: 12),
                              Expanded(child: StatCard(title: 'TOTAL EXAMS', val: '12', color: AppColors.onSurfaceVariant, icon: Icons.assignment)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                          Text('SUBJECT PERFORMANCE', style: AppTextStyles.labelXsUppercase.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.cardSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineLight)),
                            child: const Column(
                              children: [
                                SubjectProgressBar(name: 'Mathematics', val: 0.85, percent: '85%'),
                                SizedBox(height: 16),
                                SubjectProgressBar(name: 'Chemistry', val: 0.78, percent: '78%'),
                                SizedBox(height: 16),
                                SubjectProgressBar(name: 'Physics', val: 0.72, percent: '72%'),
                                SizedBox(height: 16),
                                SubjectProgressBar(name: 'Biology', val: 0.89, percent: '89%'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                          Text('RECENT REPORTS', style: AppTextStyles.labelXsUppercase.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          const ReportItem(name: 'Chemistry Mid-Term Consolidated.pdf', size: '1.2 MB', subject: 'Chemistry'),
                          const ReportItem(name: 'Physics Unit Test Summary.pdf', size: '850 KB', subject: 'Physics'),
                          const ReportItem(name: 'DTS - 07 Academic Final Ledger.xlsx', size: '3.4 MB', subject: 'All Subjects'),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _activeSubTab == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed('/exam-create');
                if (result == true) {
                  _refreshExams();
                } else if (result != null && result is Map<String, dynamic>) {
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
