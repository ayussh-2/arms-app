import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/graphql/queries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/arms_picker_sheet.dart';
import '../../widgets/arms_section_card.dart';
import '../../widgets/arms_segmented_control.dart';
import '../../widgets/arms_snackbar.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/components/arms_avatar.dart';
import 'models/scorecard_models.dart';
import 'utils/scorecard_pdf_generator.dart';
import 'widgets/attendance_month_carousel_widget.dart';
import 'widgets/benchmark_bar_widget.dart';
import 'widgets/scorecard_chart_widget.dart';

/// Primary screen for displaying a student's holistic academic scorecard.
/// Includes KPI overview, fl_chart visualizations, grouped exam breakdown with benchmark bars,
/// swipeable attendance calendar, comments timeline, and instant PDF export.
class StudentScorecardScreen extends StatefulWidget {
  const StudentScorecardScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.rollNo,
    this.className,
    this.sectionName,
    this.imageUrl,
    this.organisationId,
    this.initialSessionYear,
  });

  final String studentId;
  final String studentName;
  final String? rollNo;
  final String? className;
  final String? sectionName;
  final String? imageUrl;
  final String? organisationId;
  final int? initialSessionYear;

  @override
  State<StudentScorecardScreen> createState() => _StudentScorecardScreenState();
}

class _StudentScorecardScreenState extends State<StudentScorecardScreen> {
  int? _selectedSessionYear;
  int _modeIndex = 0; // 0: Series Wise, 1: Subject Wise
  String? _selectedGroupKey; // null: All Groups
  final Set<String> _expandedExamIds = <String>{};
  final Set<String> _collapsedGroupKeys = <String>{};
  bool _isLoading = false;
  String? _errorMessage;
  StudentAcademicScorecard? _scorecard;

  String get _currentMode => _modeIndex == 0 ? 'series' : 'subject';

  String _formatScorecardDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final trimmed = raw.trim();
    try {
      final dt = DateTime.parse(trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = (dt.year % 100).toString().padLeft(2, '0');
      return '$day $month $year';
    } catch (_) {
      return trimmed;
    }
  }

  String get _effectiveOrgId {
    if (widget.organisationId != null && widget.organisationId!.isNotEmpty) {
      return widget.organisationId!;
    }
    return AuthService.currentAdmin?.organization?.id ?? '';
  }

  @override
  void initState() {
    super.initState();
    _selectedSessionYear = widget.initialSessionYear;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchScorecard();
    });
  }

  Future<void> _fetchScorecard() async {
    final orgId = _effectiveOrgId;
    if (orgId.isEmpty) {
      setState(() {
        _errorMessage = 'Organization context is missing. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final variables = <String, dynamic>{
        'studentId': widget.studentId,
        'organisationId': orgId,
        'mode': _currentMode,
      };

      if (_selectedSessionYear != null) {
        variables['sessionYear'] = _selectedSessionYear;
      }

      debugPrint('\n================ [SCORECARD QUERY EXECUTION] ================');
      debugPrint('[SCORECARD] Target Student ID   : ${widget.studentId}');
      debugPrint('[SCORECARD] Target Student Name : ${widget.studentName}');
      debugPrint('[SCORECARD] Organization ID     : $orgId');
      debugPrint('[SCORECARD] Grouping Mode       : $_currentMode');
      debugPrint('[SCORECARD] Session Year Filter : $_selectedSessionYear');
      debugPrint('[SCORECARD] Variables           : $variables');
      debugPrint('[SCORECARD] Query Document:\n${GqlQueries.getStudentAcademicScorecard}');
      debugPrint('=============================================================\n');

      final startTime = DateTime.now();
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getStudentAcademicScorecard),
          variables: variables,
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[SCORECARD] Query returned in ${elapsedMs}ms');

      if (result.hasException) {
        final exception = result.exception;
        debugPrint('❌ [SCORECARD HAS EXCEPTION]');
        debugPrint('GraphQL Errors: ${exception?.graphqlErrors}');
        debugPrint('Link Exception: ${exception?.linkException}');
        debugPrint('Raw Exception : $exception');

        String message = 'Failed to load academic scorecard.';
        if (exception?.graphqlErrors.isNotEmpty ?? false) {
          message = exception!.graphqlErrors.first.message;
        } else if (exception?.linkException != null) {
          message = exception!.linkException.toString();
        }
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
        return;
      }

      final data = result.data?['studentAcademicScorecard'] as Map<String, dynamic>?;
      debugPrint('✅ [SCORECARD RAW RESPONSE RECEIVED]');
      debugPrint('[SCORECARD] raw data null? ${result.data == null}');
      debugPrint('[SCORECARD] studentAcademicScorecard null? ${data == null}');
      if (data != null) {
        debugPrint('[SCORECARD] overview: ${data['overview']}');
        debugPrint('[SCORECARD] groups count: ${(data['groups'] as List?)?.length}');
        debugPrint('[SCORECARD] historical sessions: ${(data['session']?['historicalSessions'] as List?)?.map((s) => s['label']).toList()}');
      }

      if (data == null) {
        setState(() {
          _errorMessage = 'No scorecard data found for this student.';
          _isLoading = false;
        });
        return;
      }

      final parsed = StudentAcademicScorecard.fromJson(data);
      debugPrint('[SCORECARD] Successfully parsed model! Groups: ${parsed.groups.length}');

      setState(() {
        _scorecard = parsed;
        _selectedSessionYear = parsed.session.selectedSessionYear;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('❌ [SCORECARD PARSING / RUNTIME ERROR]: $e\n$st');
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  void _onModeChanged(int newIndex) {
    if (_modeIndex == newIndex) return;
    setState(() {
      _modeIndex = newIndex;
    });
    _fetchScorecard();
  }

  void _openSessionPicker() {
    final scorecard = _scorecard;
    if (scorecard == null) return;

    final sessions = scorecard.session.historicalSessions;
    if (sessions.isEmpty) {
      ArmsSnackbar.showInfo(context, 'No historical sessions available.');
      return;
    }

    ArmsPickerSheet.show<ScorecardHistoricalSession>(
      context: context,
      title: 'Select Academic Session',
      items: sessions,
      itemLabel: (item) {
        final isCurrent = item.year == scorecard.session.currentSessionYear;
        return '${item.label}${isCurrent ? ' (Current)' : ''}';
      },
      selectedItem: sessions.cast<ScorecardHistoricalSession?>().firstWhere(
            (s) => s?.year == _selectedSessionYear,
            orElse: () => null,
          ),
      onItemSelected: (item) {
        if (_selectedSessionYear != item.year) {
          setState(() {
            _selectedSessionYear = item.year;
          });
          _fetchScorecard();
        }
      },
    );
  }

  void _onSharePdf() {
    final scorecard = _scorecard;
    if (scorecard == null) {
      ArmsSnackbar.showInfo(context, 'Scorecard is still loading.');
      return;
    }
    ScorecardPdfGenerator.shareScorecardPdf(
      context: context,
      scorecard: scorecard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ArmsTopAppBar(
        title: 'Academic Scorecard',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textMain),
            tooltip: 'Share PDF',
            onPressed: _scorecard != null ? _onSharePdf : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _scorecard == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _scorecard == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 54, color: AppColors.errorText),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchScorecard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final scorecard = _scorecard;
    if (scorecard == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchScorecard,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginPage,
          vertical: AppSpacing.stackMd,
        ),
        children: [
          // 1. Student Header Card
          _buildStudentHeader(scorecard),
          const SizedBox(height: 14),

          // 2. Academic Session Banner & Selector
          _buildSessionSelector(scorecard),
          const SizedBox(height: 16),

          // 3. Overall KPI Overview Cards
          _buildKpiOverviewGrid(scorecard.overview),
          const SizedBox(height: 20),

          // 4. View Switcher: Series Wise vs Subject Wise
          ArmsSegmentedControl(
            options: const ['Series Wise', 'Subject Wise'],
            selectedIndex: _modeIndex,
            onChanged: _onModeChanged,
          ),
          const SizedBox(height: 20),

          // 5. Overall Performance Chart
          ScorecardChartWidget(
            chartData: scorecard.overallCharts,
            title: 'Overall Performance Trend',
          ),
          const SizedBox(height: 24),

          // 6. Grouped Exam Performance Cards
          _buildGroupedExamSections(scorecard.groups),
          const SizedBox(height: 16),

          // 7. Attendance Calendar Section
          ArmsSectionCard(
            title: 'Attendance Calendar',
            child: AttendanceMonthCarouselWidget(attendance: scorecard.attendance),
          ),

          // 8. Qualitative Tags & Remarks Timeline
          if (scorecard.tags.isNotEmpty || scorecard.comments.isNotEmpty) ...[
            _buildTagsAndCommentsSection(scorecard),
            const SizedBox(height: 24),
          ],

          // Footer info
          Center(
            child: Text(
              '${scorecard.session.label} Session • Pull to refresh',
              style: AppTextStyles.labelXs.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStudentHeader(StudentAcademicScorecard scorecard) {
    final student = scorecard.student;
    final displayName = student.name.isNotEmpty ? student.name : widget.studentName;
    final displayRoll = student.rollNo?.toString() ?? widget.rollNo ?? '-';
    final displayClass = student.className ?? widget.className ?? '';
    final displaySection = student.sectionName ?? widget.sectionName ?? '';
    final classSecText = [displayClass, if (displaySection.isNotEmpty) '($displaySection)'].join(' ').trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          ArmsAvatar(
            imageUrl: student.imageUrl ?? widget.imageUrl,
            name: displayName,
            radius: 28,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.headerSmall.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Roll: $displayRoll',
                        style: AppTextStyles.labelXs.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                    if (classSecText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          classSecText,
                          style: AppTextStyles.labelXs.copyWith(
                            color: AppColors.textSecondary,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSelector(StudentAcademicScorecard scorecard) {
    return InkWell(
      onTap: _openSessionPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.textMain),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic Session: ${scorecard.session.label}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textMain,
                    ),
                  ),
                  Text(
                    '${_formatScorecardDate(scorecard.session.fromDate)} to ${_formatScorecardDate(scorecard.session.toDate)}',
                    style: AppTextStyles.labelXs.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiOverviewGrid(ScorecardOverview overview) {
    final pctStr = overview.overallPercentage != null ? '${overview.overallPercentage!.toStringAsFixed(2)}%' : '-';
    final rankStr = overview.overallRank != null
        ? (overview.totalParticipants != null && overview.totalParticipants! > 0
            ? '#${overview.overallRank!.toInt()} / ${overview.totalParticipants}'
            : '#${overview.overallRank!.toInt()}')
        : '-';
    final marksStr = '${overview.overallObtained.toStringAsFixed(0)} / ${overview.overallMaxMarks.toStringAsFixed(0)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // 3 cards: on wider screen 3 columns or on mobile 3 cards nicely laid out
        final cardWidth = (totalWidth - 16) / 3;

        return Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                width: cardWidth,
                title: 'Overall Marks',
                value: marksStr,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                width: cardWidth,
                title: 'Overall Score',
                value: pctStr,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                width: cardWidth,
                title: 'Class Rank',
                value: rankStr,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelXs.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedExamSections(List<ScorecardGroup> groups) {
    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'No exam records recorded for this session.',
          style: AppTextStyles.labelXs,
        ),
      );
    }

    final totalExamsCount = groups.fold<int>(0, (sum, g) => sum + g.exams.length);
    final displayedGroups = _selectedGroupKey == null
        ? groups
        : groups.where((g) => g.key == _selectedGroupKey).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown Selector to Filter / View Exams by Group
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedGroupKey,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      const Icon(Icons.ballot_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'All Exam Groups ($totalExamsCount exams)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                ...groups.map(
                  (g) => DropdownMenuItem<String?>(
                    value: g.key,
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${g.label} (${g.exams.length} ${g.exams.length == 1 ? 'exam' : 'exams'})',
                            style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedGroupKey = val;
                });
              },
            ),
          ),
        ),

        // List of Group Cards
        ...displayedGroups.map((group) => _buildGroupCard(group)),
      ],
    );
  }

  Widget _buildGroupCard(ScorecardGroup group) {
    // Sort exams by latest date first
    final sortedExams = [...group.exams]..sort((a, b) {
        final da = a.examDate ?? '';
        final db = b.examDate ?? '';
        final cmp = db.compareTo(da);
        return cmp != 0 ? cmp : b.examName.compareTo(a.examName);
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.label,
                        style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sortedExams.length} ${sortedExams.length == 1 ? 'Exam' : 'Exams'} in group (Latest first)',
                        style: AppTextStyles.labelXs.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (group.averagePercentage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Avg: ${group.averagePercentage!.toStringAsFixed(2)}%',
                      style: AppTextStyles.labelXs.copyWith(
                        color: AppColors.successText,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Group Sub-Chart (sorted by dates latest first)
          if (group.charts.percentage.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final examDateMap = {for (final e in group.exams) e.examName: e.examDate ?? ''};
                List<ScorecardChartPoint> sortByLatestDate(List<ScorecardChartPoint> list) {
                  final sorted = [...list];
                  sorted.sort((a, b) {
                    final da = examDateMap[a.label] ?? '';
                    final db = examDateMap[b.label] ?? '';
                    final cmp = db.compareTo(da);
                    return cmp != 0 ? cmp : b.label.compareTo(a.label);
                  });
                  return sorted;
                }

                return ScorecardChartWidget(
                  chartData: ScorecardChartData(
                    percentage: sortByLatestDate(group.charts.percentage),
                    marks: sortByLatestDate(group.charts.marks),
                    rank: sortByLatestDate(group.charts.rank),
                  ),
                  height: 180,
                  backgroundColor: AppColors.background,
                  showBorder: true,
                );
              },
            ),
            const SizedBox(height: 10),
          ],

          // Collapsible Button to Hide/Show All Exams of this Group
          InkWell(
            onTap: () {
              setState(() {
                if (_collapsedGroupKeys.contains(group.key)) {
                  _collapsedGroupKeys.remove(group.key);
                } else {
                  _collapsedGroupKeys.add(group.key);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _collapsedGroupKeys.contains(group.key)
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _collapsedGroupKeys.contains(group.key)
                        ? 'Show ${sortedExams.length} ${sortedExams.length == 1 ? 'Exam' : 'Exams'}'
                        : 'Hide ${sortedExams.length} ${sortedExams.length == 1 ? 'Exam' : 'Exams'}',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // List of Distinct Exam Cards (Full width, no double-padding, hidden if collapsed)
          if (!_collapsedGroupKeys.contains(group.key))
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: sortedExams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _buildExamRow(sortedExams[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExamRow(ScorecardExamRow exam) {
    final isExpanded = _expandedExamIds.contains(exam.examId);
    final pctStr = exam.percentage != null ? '${exam.percentage!.toStringAsFixed(2)}%' : '-';
    final rankStr = exam.rank != null ? '#${exam.rank}' : '-';
    final obtainedStr = '${exam.obtained.toStringAsFixed(1)} / ${exam.maxMarks.toStringAsFixed(0)}';
    final formattedDate = _formatScorecardDate(exam.examDate);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: exam.subjects.isNotEmpty
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedExamIds.remove(exam.examId);
                    } else {
                      _expandedExamIds.add(exam.examId);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Exam Name & Date (Utilizes full width)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        exam.examName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: AppTextStyles.labelXs.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Badges row with clean neutral styling
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Student Score & Percentage
                    _buildMetricBadge(
                      icon: Icons.stars_rounded,
                      iconColor: AppColors.primary,
                      label: '$pctStr ($obtainedStr)',
                      textColor: AppColors.textMain,
                      isBold: true,
                    ),

                    // 2. Class Average Badge
                    if (exam.averagePercentage != null)
                      _buildMetricBadge(
                        icon: Icons.bar_chart_rounded,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Avg: ${exam.averagePercentage!.toStringAsFixed(2)}%',
                        textColor: AppColors.textMain,
                      ),

                    // 3. Rank Badge — right beside Average!
                    if (exam.rank != null)
                      _buildMetricBadge(
                        icon: Icons.emoji_events_rounded,
                        iconColor: const Color(0xFFD97706),
                        label: exam.participants > 0 ? 'Rank: $rankStr / ${exam.participants}' : 'Rank: $rankStr',
                        textColor: const Color(0xFFB45309),
                        isBold: true,
                      ),

                    // 4. Best Topper Badge
                    if (exam.bestPercentage != null)
                      _buildMetricBadge(
                        icon: Icons.military_tech_rounded,
                        iconColor: const Color(0xFF16A34A),
                        label: 'Top: ${exam.bestPercentage!.toStringAsFixed(2)}%',
                        textColor: AppColors.textMain,
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Row 3: Inline Benchmark Bar (Full Width with breathing room)
                BenchmarkBarWidget(
                  studentPercentage: exam.percentage,
                  bestPercentage: exam.bestPercentage,
                  averagePercentage: exam.averagePercentage,
                ),

                // Row 4: Subject toggle hint
                if (exam.subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${exam.subjects.length} ${exam.subjects.length == 1 ? 'subject' : 'subjects'} tested',
                        style: AppTextStyles.labelXs.copyWith(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      Text(
                        isExpanded ? 'Hide subjects' : 'View subjects',
                        style: AppTextStyles.labelXs.copyWith(
                          fontSize: 11.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                // Subject Breakdown (Smoothly expanded)
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  ...exam.subjects.map((sub) => _buildSubjectRow(sub)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color textColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelXs.copyWith(
              color: textColor,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(ScorecardSubjectCell sub) {
    final subPctStr = sub.percentage != null ? '${sub.percentage!.toStringAsFixed(2)}%' : '-';
    final subRankStr = sub.rank != null ? '#${sub.rank}' : '-';
    final subObtainedStr = '${sub.obtained?.toStringAsFixed(1) ?? '-'}/${sub.maxMarks.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.subjectName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub.status != null && sub.status!.isNotEmpty && sub.status!.toLowerCase() != 'normal')
                  Text(
                    sub.status!,
                    style: AppTextStyles.labelXs.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.errorText,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subObtainedStr,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subPctStr,
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                  ),
                  if (sub.rank != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Rank $subRankStr',
                      style: AppTextStyles.labelXs.copyWith(
                        color: const Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsAndCommentsSection(StudentAcademicScorecard scorecard) {
    return ArmsSectionCard(
      title: 'Remarks & Attributes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags row
          if (scorecard.tags.isNotEmpty) ...[
            Text(
              'TAGS',
              style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: scorecard.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineLight),
                  ),
                  child: Text(
                    tag,
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Comments timeline
          if (scorecard.comments.isNotEmpty) ...[
            Text(
              'FACULTY REMARKS',
              style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scorecard.comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final comment = scorecard.comments[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${comment.authorName} (${comment.authorType.toUpperCase()})',
                            style: AppTextStyles.labelXs.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                          if (comment.createdAt != null)
                            Text(
                              _formatScorecardDate(comment.createdAt),
                              style: AppTextStyles.labelXs.copyWith(fontSize: 10),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.commentText,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
