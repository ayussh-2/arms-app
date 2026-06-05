import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/exam_lookup_cache.dart';
import '../../core/services/exam_pdf_generator.dart';
import '../../core/utils/exam_html_generator.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_input_field.dart';
import '../../widgets/arms_snackbar.dart';
import 'widgets/exam_view_widgets.dart';
import 'widgets/exam_view_sheets.dart';

class ExamViewScreen extends StatefulWidget {
  const ExamViewScreen({super.key});

  @override
  State<ExamViewScreen> createState() => _ExamViewScreenState();
}

class _ExamViewScreenState extends State<ExamViewScreen> {
  Map<String, dynamic>? _exam;
  List<Map<String, dynamic>> _marks = [];
  List<Map<String, dynamic>> _filteredMarks = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  String downloadSelection = 'All students';
  String downloadFormat = 'PDF Format';

  int _currentPage = 0;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterMarks);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _exam = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_exam != null) _loadMarks();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMarks({bool forceRefresh = false}) async {
    try {
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getExamDetails),
          variables: {'examId': _exam!['id'], 'organisationId': orgId},
          fetchPolicy: forceRefresh ? FetchPolicy.networkOnly : FetchPolicy.cacheAndNetwork,
        ),
      );
      if (!mounted) return;
      if (result.hasException) {
        ArmsSnackbar.showError(context, 'Failed to load exam details: ${result.exception.toString()}');
        setState(() => _isLoading = false);
        return;
      }

      final details = result.data?['getExamDetails'] as Map<String, dynamic>?;
      if (details != null) {
        final examData = details['exam'] as Map<String, dynamic>?;
        final rawMarks = (details['marks'] as List? ?? []).cast<Map<String, dynamic>>();
        final students = (details['students'] as List? ?? []).cast<Map<String, dynamic>>();
        final subjects = (details['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

        final studentMarksGrouped = <String, List<Map<String, dynamic>>>{};
        for (final m in rawMarks) {
          final sId = m['student_id'] as String? ?? '';
          if (sId.isNotEmpty) {
            studentMarksGrouped.putIfAbsent(sId, () => []).add(m);
          }
        }

        final enrichedMarks = <Map<String, dynamic>>[];
        for (final student in students) {
          final sId = student['id'] as String? ?? '';
          final studentMarks = studentMarksGrouped[sId] ?? [];

          double totalObtained = 0.0;
          bool anyAttempted = false;
          bool allAbsent = studentMarks.isNotEmpty;

          for (final m in studentMarks) {
            final isAbsent = m['is_absent'] == true;
            if (!isAbsent) {
              allAbsent = false;
              final marks = m['marks_obtained'] as num?;
              if (marks != null) {
                totalObtained += marks.toDouble();
                anyAttempted = true;
              }
            }
          }

          enrichedMarks.add({
            'student_id': sId,
            'student': student,
            'is_absent': studentMarks.isEmpty ? false : allAbsent,
            'marks_obtained': anyAttempted ? totalObtained : null,
          });
        }

        enrichedMarks.sort((a, b) {
          final aAbsent = a['is_absent'] == true;
          final bAbsent = b['is_absent'] == true;
          if (aAbsent && bAbsent) return 0;
          if (aAbsent) return 1;
          if (bAbsent) return -1;

          final aMarks = a['marks_obtained'] as num?;
          final bMarks = b['marks_obtained'] as num?;
          if (aMarks == null && bMarks == null) return 0;
          if (aMarks == null) return 1;
          if (bMarks == null) return -1;

          return bMarks.toDouble().compareTo(aMarks.toDouble());
        });

        setState(() {
          if (examData != null) {
            _exam = {..._exam!, ...examData, 'subjects': subjects};
          }
          _marks = enrichedMarks;
          _filteredMarks = enrichedMarks;
          _isLoading = false;
        });
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

  void _filterMarks() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _currentPage = 0;
      if (q.isEmpty) {
        _filteredMarks = _marks;
      } else {
        _filteredMarks = _marks.where((m) {
          final name = (m['student']?['name'] as String? ?? '').toLowerCase();
          final roll = (m['student']?['roll_no']?.toString() ?? '');
          return name.contains(q) || roll.contains(q);
        }).toList();
      }
    });
  }

  String _parseMeta(dynamic val, String type) {
    if (val == null) return 'All';
    final str = val.toString().trim();
    if (str.isEmpty || str == '[]' || str == 'null') return 'All';

    final clean = str
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", "")
        .trim();
    if (clean.isEmpty) return 'All';

    final parts = clean
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'All';

    final resolvedNames = <String>[];
    for (final part in parts) {
      final isUuid = part.contains('-') && part.length > 15;
      if (isUuid) {
        resolvedNames.add(ExamLookupCache.resolve(part, type));
      } else {
        resolvedNames.add(part);
      }
    }

    return resolvedNames.join(', ');
  }

  void _showDownloadSheet() {
    showDownloadResultsSheet(
      context: context,
      initialSelection: downloadSelection,
      initialFormat: downloadFormat,
      onConfirm: (selection, format) async {
        setState(() {
          downloadSelection = selection;
          downloadFormat = format;
        });
        if (format == 'PDF Format') {
          await ExamPdfGenerator.handleGeneratePdf(
            context: context,
            exam: _exam!,
            prefs: ExamReportPreferences(
              isMultiExam: false,
              includeStudentPic: false,
              showMaxMarks: true,
              showGrandTotal: true,
              showOverallPercentage: true,
              showOverallRank: true,
              orientation: 'portrait',
            ),
            bottomSheetContext: context,
          );
        } else {
          ArmsSnackbar.showSuccess(context, 'Exporting $selection as Excel Sheet...');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_exam == null) {
      return const Scaffold(body: Center(child: Text('No exam data')));
    }

    final subjects = _exam!['subjects'] as List? ?? [];
    final subjectNames = subjects.map((s) => s['name'] ?? '').join(', ');
    final totalMarks = _exam!['total_marks'] ?? 0;

    final pageMarks = _filteredMarks.skip(_currentPage * _pageSize).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ArmsTopAppBar(
        title: 'Exam Details',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadMarks(forceRefresh: true);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: AppSpacing.stackMd),
                      _buildHeaderCard(subjectNames, totalMarks),
                      const SizedBox(height: AppSpacing.stackLg),
                      _buildQuickActions(),
                      const SizedBox(height: AppSpacing.stackLg),
                      Row(
                        children: [
                          Text('Student Marks', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      ArmsInputField(controller: _searchCtrl, hintText: 'Search students...', prefixIcon: Icons.search),
                      const SizedBox(height: AppSpacing.stackMd),
                      _buildTableHeader(),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildMarkRow((_currentPage * _pageSize) + i, pageMarks[i], totalMarks),
                      childCount: pageMarks.length,
                    ),
                  ),
                ),
                if (_filteredMarks.length > _pageSize)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${(_currentPage * _pageSize) + 1} to ${((_currentPage + 1) * _pageSize).clamp(1, _filteredMarks.length)} of ${_filteredMarks.length}',
                              style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                            Row(
                              children: [
                                PaginationButton(
                                  icon: Icons.chevron_left,
                                  isEnabled: _currentPage > 0,
                                  onTap: () => setState(() => _currentPage--),
                                ),
                                const SizedBox(width: 8),
                                PaginationButton(
                                  icon: Icons.chevron_right,
                                  isEnabled: (_currentPage + 1) * _pageSize < _filteredMarks.length,
                                  onTap: () => setState(() => _currentPage++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
                  sliver: SliverList(delegate: SliverChildListDelegate([const SizedBox(height: 120)])),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/mark-entry', arguments: _exam);
          setState(() => _isLoading = true);
          _loadMarks(forceRefresh: true);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.edit),
        label: const Text('Edit'),
      ),
    );
  }

  Widget _buildHeaderCard(String subjectNames, int totalMarks) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXAM TITLE', style: AppTextStyles.labelXsUppercase.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(_exam!['name'] ?? '', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subjectNames, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.outlineLight),
          const SizedBox(height: 16),
          Row(
            children: [
              HeaderMeta(label: 'DATE', value: _formatExamDate(_exam!['exam_date'])),
              HeaderMeta(label: 'TOTAL MARKS', value: '$totalMarks Marks'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HeaderMeta(label: 'SCHOOL', value: _parseMeta(_exam!['for_school'], 'school')),
              HeaderMeta(label: 'CLASS / SECTION', value: '${_parseMeta(_exam!['for_class'], 'class')} / ${_parseMeta(_exam!['for_section'], 'section')}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HeaderMeta(
                label: 'TOPICS',
                value: (_exam!['topic'] != null && _exam!['topic'].toString().trim().isNotEmpty)
                    ? _exam!['topic'].toString()
                    : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChipWidget(
            icon: Icons.description_outlined,
            label: 'Attendance PDF',
            onTap: () async {
              final url = _exam!['attendance_pdf_url'] as String? ?? '';
              if (url.isNotEmpty) {
                try {
                  final uri = Uri.parse(url);
                  final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!success && context.mounted) {
                    ArmsSnackbar.showWarning(context, 'Could not launch URL: $url');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ArmsSnackbar.showWarning(context, 'Error launching URL: $e');
                  }
                }
              } else {
                ArmsSnackbar.showWarning(context, 'Attendance PDF not uploaded');
              }
            },
          ),
          const SizedBox(width: 8),
          ActionChipWidget(
            icon: Icons.quiz_outlined,
            label: 'Question Paper',
            onTap: () async {
              final url = _exam!['question_pdf_url'] as String? ?? '';
              if (url.isNotEmpty) {
                try {
                  final uri = Uri.parse(url);
                  final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!success && context.mounted) {
                    ArmsSnackbar.showWarning(context, 'Could not launch URL: $url');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ArmsSnackbar.showWarning(context, 'Error launching URL: $e');
                  }
                }
              } else {
                ArmsSnackbar.showWarning(context, 'Question Paper PDF not uploaded');
              }
            },
          ),
          const SizedBox(width: 8),
          ActionChipWidget(
            icon: Icons.download_outlined,
            label: 'Results',
            onTap: _showDownloadSheet,
          ),
          const SizedBox(width: 8),
          ActionChipWidget(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: AppColors.errorText,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text('Are you sure you want to delete this exam draft?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        ArmsSnackbar.showError(context, 'Exam marked as soft-deleted.');
                      },
                      child: const Text('Delete', style: TextStyle(color: AppColors.errorText)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final style = AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, letterSpacing: 1.5, color: AppColors.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceVariant))),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('SN', style: style)),
          Expanded(child: Text('STUDENT DETAILS', style: style)),
          SizedBox(width: 80, child: Text('MARKS', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildMarkRow(int index, Map<String, dynamic> mark, int totalMarks) {
    final student = mark['student'] as Map<String, dynamic>? ?? {};
    final isAbsent = mark['is_absent'] == true;
    final marksObtained = mark['marks_obtained'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.outlineFaint))),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text((index + 1).toString().padLeft(2, '0'), style: AppTextStyles.labelXs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] ?? '', style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain)),
                Text('Roll: ${student['roll_no'] ?? ''}', style: AppTextStyles.labelXs.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: isAbsent
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(9999)),
                      child: Text('Absent', style: AppTextStyles.labelXsUppercase.copyWith(color: AppColors.errorText, fontSize: 10)),
                    ),
                  )
                : RichText(
                    textAlign: TextAlign.right,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${marksObtained?.toInt() ?? 0}',
                          style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        TextSpan(
                          text: '/$totalMarks',
                          style: AppTextStyles.labelXs.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatExamDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 'N/A';
    try {
      final parsedDate = DateTime.parse(dateStr.trim());
      return DateFormat('d MMM yyyy').format(parsedDate);
    } catch (_) {
      return dateStr;
    }
  }
}
