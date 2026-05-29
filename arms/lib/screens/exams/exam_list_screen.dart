import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _allExams = [];
  List<Map<String, dynamic>> _filteredExams = [];
  bool _isLoading = true;

  // Pagination State
  int _offset = 0;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Tab State: 0 = Exams, 1 = Reports
  int _activeSubTab = 0;

  // Filter States
  String? _selectedSeries;
  String? _selectedSubject;
  String? _selectedSchool;
  String? _selectedClass;
  String? _selectedSection;

  // Lookups data from GetExamLookups
  List<Map<String, dynamic>> _schoolsLookup = [];
  List<Map<String, dynamic>> _classesLookup = [];
  List<Map<String, dynamic>> _sectionsLookup = [];
  List<Map<String, dynamic>> _seriesLookup = [];
  List<Map<String, dynamic>> _subjectsLookup = [];

  // Pre-computed Map lookups for instant O(1) rendering in _ExamCard
  Map<String, String> _schoolsMap = {};
  Map<String, String> _classesMap = {};
  Map<String, String> _sectionsMap = {};

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
          variables: {
            'organisationId': orgId,
          },
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        debugPrint('Failed to load exam lookups: ${result.exception.toString()}');
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

          _schoolsMap = { for (var item in _schoolsLookup) item['id']: item['name'] ?? '' };
          _classesMap = { for (var item in _classesLookup) item['id']: item['name'] ?? '' };
          _sectionsMap = { for (var item in _sectionsLookup) item['id']: item['name'] ?? '' };
        });
      }
    } catch (e) {
      debugPrint('Error loading exam lookups: $e');
    }
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
        setState(() {
          _isLoading = false;
        });
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

      final variables = <String, dynamic>{
        'organisationId': orgId,
        'isDeleted': false,
        'pagination': {
          'limit': _limit,
          'offset': _offset,
        },
      };

      if (isSearch) {
        variables['query'] = _searchController.text.trim();
      } else if (hasServerFilters) {
        variables['query'] = '';
      }

      if (hasServerFilters) {
        final filters = <String, dynamic>{};
        if (_selectedSeriesId != null) {
          filters['seriesIds'] = [_selectedSeriesId];
        }
        if (_selectedClassId != null) {
          filters['classIds'] = [_selectedClassId];
        }
        if (_selectedSubjectId != null) {
          filters['subjectIds'] = [_selectedSubjectId];
        }
        if (_selectedSchoolId != null) {
          filters['schoolIds'] = [_selectedSchoolId];
        }
        if (_selectedSectionId != null) {
          filters['sectionIds'] = [_selectedSectionId];
        }
        variables['filters'] = filters;
      }

      final result = await client.query(
        QueryOptions(
          document: gql(queryStr),
          variables: variables,
          fetchPolicy: forceRefresh ? FetchPolicy.networkOnly : FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load exams: ${result.exception.toString()}'),
            backgroundColor: AppColors.errorText,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final queryKey = (isSearch || hasServerFilters) ? 'searchExams' : 'getExamsPaginated';
      final responseData = result.data?[queryKey];
      final items = (responseData?['items'] as List? ?? []).cast<Map<String, dynamic>>();
      final paginationInfo = responseData?['pagination'] as Map<String, dynamic>?;

      setState(() {
        _allExams = items;
        if (paginationInfo != null) {
          _hasMore = paginationInfo['hasMore'] as bool? ?? false;
        } else {
          _hasMore = items.length >= _limit;
        }
        _isLoading = false;
      });

      _filterExams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreExams() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() {
          _isLoadingMore = false;
        });
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

      final variables = <String, dynamic>{
        'organisationId': orgId,
        'isDeleted': false,
        'pagination': {
          'limit': _limit,
          'offset': nextOffset,
        },
      };

      if (isSearch) {
        variables['query'] = _searchController.text.trim();
      } else if (hasServerFilters) {
        variables['query'] = '';
      }

      if (hasServerFilters) {
        final filters = <String, dynamic>{};
        if (_selectedSeriesId != null) {
          filters['seriesIds'] = [_selectedSeriesId];
        }
        if (_selectedClassId != null) {
          filters['classIds'] = [_selectedClassId];
        }
        if (_selectedSubjectId != null) {
          filters['subjectIds'] = [_selectedSubjectId];
        }
        if (_selectedSchoolId != null) {
          filters['schoolIds'] = [_selectedSchoolId];
        }
        if (_selectedSectionId != null) {
          filters['sectionIds'] = [_selectedSectionId];
        }
        variables['filters'] = filters;
      }

      final result = await client.query(
        QueryOptions(
          document: gql(queryStr),
          variables: variables,
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more exams: ${result.exception.toString()}'),
            backgroundColor: AppColors.errorText,
          ),
        );
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      final queryKey = (isSearch || hasServerFilters) ? 'searchExams' : 'getExamsPaginated';
      final responseData = result.data?[queryKey];
      final items = (responseData?['items'] as List? ?? []).cast<Map<String, dynamic>>();
      final paginationInfo = responseData?['pagination'] as Map<String, dynamic>?;

      setState(() {
        _offset = nextOffset;
        _allExams.addAll(items);
        if (paginationInfo != null) {
          _hasMore = paginationInfo['hasMore'] as bool? ?? false;
        } else {
          _hasMore = items.length >= _limit;
        }
        _isLoadingMore = false;
      });

      _filterExams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshExams() async {
    _loadLookups();
    await _resetAndLoadExams(forceRefresh: true);
  }

  // Dynamic lists from loaded data
  List<String> get uniqueSeries {
    return _seriesLookup
        .map((e) => e['name'] as String?)
        .whereType<String>()
        .toList();
  }

  List<String> get uniqueSubjects {
    return _subjectsLookup
        .map((e) => e['name'] as String?)
        .whereType<String>()
        .toList();
  }

  List<String> get uniqueSchools {
    return _schoolsLookup
        .map((e) => e['name'] as String?)
        .whereType<String>()
        .toList();
  }

  List<String> get uniqueClasses {
    return _classesLookup
        .map((e) => e['name'] as String?)
        .whereType<String>()
        .toList();
  }

  List<String> get uniqueSections {
    return _sectionsLookup
        .map((e) => e['name'] as String?)
        .whereType<String>()
        .toList();
  }

  String? get _selectedSeriesId {
    if (_selectedSeries == null) return null;
    final found = _seriesLookup.firstWhere(
      (e) => e['name'] == _selectedSeries,
      orElse: () => <String, dynamic>{},
    );
    return found['id'] as String?;
  }

  String? get _selectedSubjectId {
    if (_selectedSubject == null) return null;
    final found = _subjectsLookup.firstWhere(
      (e) => e['name'] == _selectedSubject,
      orElse: () => <String, dynamic>{},
    );
    return found['id'] as String?;
  }

  String? get _selectedClassId {
    if (_selectedClass == null) return null;
    final found = _classesLookup.firstWhere(
      (e) => e['name'] == _selectedClass,
      orElse: () => <String, dynamic>{},
    );
    return found['id'] as String?;
  }

  String? get _selectedSchoolId {
    if (_selectedSchool == null) return null;
    final found = _schoolsLookup.firstWhere(
      (e) => e['name'] == _selectedSchool,
      orElse: () => <String, dynamic>{},
    );
    return found['id'] as String?;
  }

  String? get _selectedSectionId {
    if (_selectedSection == null) return null;
    final found = _sectionsLookup.firstWhere(
      (e) => e['name'] == _selectedSection,
      orElse: () => <String, dynamic>{},
    );
    return found['id'] as String?;
  }

  void _filterExams() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredExams = _allExams.where((e) {
        // Search filter (client-side backup/refinement)
        final name = (e['name'] as String? ?? '').toLowerCase();
        final series = (e['series']?['name'] as String? ?? '').toLowerCase();
        final subjects = e['subjects'] as List? ?? [];
        final subjectNames = subjects.map((s) => (s['name'] as String? ?? '').toLowerCase()).join(' ');

        final matchesSearch = q.isEmpty ||
            name.contains(q) ||
            series.contains(q) ||
            subjectNames.contains(q);

        return matchesSearch;
      }).toList();
    });

    // Auto-load more if filters returned no matches but there is more data in the backend
    if (_filteredExams.isEmpty && _hasMore && !_isLoadingMore && !_isLoading && _activeSubTab == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMoreExams();
      });
    }
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
                        '${exam['series']?['name'] ?? ''} • ${_formatExamDate(exam['exam_date'])}',
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
      body: _activeSubTab == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed Header: Title, Search, Filters
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 60, AppSpacing.marginPage, 16),
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
                            onPressed: _refreshExams,
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
                                setState(() {
                                  _selectedSeries = val;
                                });
                                _resetAndLoadExams();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Subjects',
                              selectedValue: _selectedSubject,
                              options: uniqueSubjects,
                              onSelected: (val) {
                                setState(() {
                                  _selectedSubject = val;
                                });
                                _resetAndLoadExams();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Schools',
                              selectedValue: _selectedSchool,
                              options: uniqueSchools,
                              onSelected: (val) {
                                setState(() {
                                  _selectedSchool = val;
                                });
                                _resetAndLoadExams();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Classes',
                              selectedValue: _selectedClass,
                              options: uniqueClasses,
                              onSelected: (val) {
                                setState(() {
                                  _selectedClass = val;
                                });
                                _resetAndLoadExams();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Sections',
                              selectedValue: _selectedSection,
                              options: uniqueSections,
                              onSelected: (val) {
                                setState(() {
                                  _selectedSection = val;
                                });
                                _resetAndLoadExams();
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
                                  });
                                  _resetAndLoadExams();
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
                    ],
                  ),
                ),
                
                // Scrollable Exam Container
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
                              : ListView.builder(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.marginPage,
                                    0,
                                    AppSpacing.marginPage,
                                    120, // Padding for bottom nav bar spacing
                                  ),
                                  itemCount: _filteredExams.length + (_isLoadingMore ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i == _filteredExams.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: CircularProgressIndicator(color: AppColors.primary),
                                        ),
                                      );
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                                      child: _ExamCard(
                                        exam: _filteredExams[i],
                                        onTap: () => _showActionSheet(_filteredExams[i]),
                                        schoolsLookup: _schoolsMap,
                                        classesLookup: _classesMap,
                                        sectionsLookup: _sectionsMap,
                                      ),
                                    );
                                  },
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

/// Individual exam card matching exam-list.html design.
class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.onTap,
    required this.schoolsLookup,
    required this.classesLookup,
    required this.sectionsLookup,
  });

  final Map<String, dynamic> exam;
  final VoidCallback onTap;
  final Map<String, String> schoolsLookup;
  final Map<String, String> classesLookup;
  final Map<String, String> sectionsLookup;

  String parseMeta(dynamic val, String type) {
    if (val == null) return 'All';
    final str = val.toString().trim();
    if (str.isEmpty || str == '[]' || str == 'null') return 'All';

    // Clean up bracket characters and quotes if any
    final clean = str.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").trim();
    if (clean.isEmpty) return 'All';

    // Handle comma-separated UUID list if any
    final parts = clean.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'All';

    final resolvedNames = <String>[];
    for (final part in parts) {
      final isUuid = part.contains('-') && part.length > 15;
      if (isUuid) {
        String? resolvedName;
        if (type == 'school') {
          resolvedName = schoolsLookup[part];
        } else if (type == 'class') {
          resolvedName = classesLookup[part];
        } else if (type == 'section') {
          resolvedName = sectionsLookup[part];
        }
        resolvedNames.add(resolvedName ?? part);
      } else {
        resolvedNames.add(part);
      }
    }

    return resolvedNames.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = exam['mark_saved'] == true;
    final subjects = exam['subjects'] as List? ?? [];
    final subjectNames = subjects.map((s) => s['name'] ?? '').join(', ');

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
                        text: _formatExamDate(exam['exam_date']),
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

/// Helper to format date from 'YYYY-MM-DD' to 'd MMM yyyy' (e.g. '29 May 2026')
String _formatExamDate(String? dateStr) {
  if (dateStr == null || dateStr.trim().isEmpty) return '';
  try {
    final parsedDate = DateTime.parse(dateStr.trim());
    return DateFormat('d MMM yyyy').format(parsedDate);
  } catch (e) {
    return dateStr;
  }
}
