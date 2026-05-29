import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../core/auth/auth_service.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_input_field.dart';

/// Exam detail/view screen matching exam-view.html.
/// Shows exam header card, quick actions, and student marks table.
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
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getExamDetails),
        variables: {
          'examId': _exam!['id'],
          'organisationId': orgId,
        },
        fetchPolicy: forceRefresh ? FetchPolicy.networkOnly : FetchPolicy.cacheAndNetwork,
      ));
      if (!mounted) return;
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load exam details: ${result.exception.toString()}'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final details = result.data?['getExamDetails'] as Map<String, dynamic>?;
      if (details != null) {
        final examData = details['exam'] as Map<String, dynamic>?;
        final rawMarks = (details['marks'] as List? ?? []).cast<Map<String, dynamic>>();
        final students = (details['students'] as List? ?? []).cast<Map<String, dynamic>>();
        final subjects = (details['subjects'] as List? ?? []).cast<Map<String, dynamic>>();

        // Create lookups
        final studentMap = { for (var s in students) s['id']: s };
        final subjectMap = { for (var s in subjects) s['id']: s };

        // Group rawMarks by student_id and aggregate marks across all subjects
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

        // Sort enriched marks by marks_obtained descending
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
            _exam = {
              ..._exam!,
              ...examData,
              'subjects': subjects,
            };
          }
          _marks = enrichedMarks;
          _filteredMarks = enrichedMarks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
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

    // Clean up bracket characters and quotes if any
    final clean = str.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").trim();
    if (clean.isEmpty) return 'All';

    return clean;
  }

  void _showDownloadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                          color: AppColors.outlineMediumLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Download Results', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('SELECTION', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 8),
                    _buildSelectionRadio(setModalState, 'All students'),
                    _buildSelectionRadio(setModalState, 'Attempted students'),
                    _buildSelectionRadio(setModalState, 'Not attempted students'),
                    const SizedBox(height: 16),
                    Text('EXPORT FORMAT', style: AppTextStyles.labelXsUppercase),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormatButton(setModalState, 'PDF Format', Icons.picture_as_pdf, AppColors.errorText),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormatButton(setModalState, 'Excel Sheet', Icons.table_chart, AppColors.successText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.download_done, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text('Exporting $downloadSelection as $downloadFormat...'),
                                ],
                              ),
                              backgroundColor: AppColors.successText,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        ),
                        child: Text(
                          'Confirm Download',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildSelectionRadio(StateSetter setModalState, String val) {
    final isSelected = downloadSelection == val;
    return GestureDetector(
      onTap: () {
        setModalState(() => downloadSelection = val);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineMediumLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(val, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain)),
            Radio<String>(
              value: val,
              groupValue: downloadSelection,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v != null) setModalState(() => downloadSelection = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(StateSetter setModalState, String format, IconData icon, Color iconColor) {
    final isSelected = downloadFormat == format;
    return GestureDetector(
      onTap: () {
        setModalState(() => downloadFormat = format);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(height: 8),
            Text(format, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain)),
          ],
        ),
      ),
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
              setState(() {
                _isLoading = true;
              });
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
                      // Header card
                      _buildHeaderCard(subjectNames, totalMarks),
                      const SizedBox(height: AppSpacing.stackLg),
                      // Quick actions
                      _buildQuickActions(),
                      const SizedBox(height: AppSpacing.stackLg),
                      // Student marks section
                      Row(
                        children: [
                          Text('Student Marks', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      ArmsInputField(controller: _searchCtrl, hintText: 'Search students...', prefixIcon: Icons.search),
                      const SizedBox(height: AppSpacing.stackMd),
                      // Table header
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
                                _PaginationButton(
                                  icon: Icons.chevron_left,
                                  isEnabled: _currentPage > 0,
                                  onTap: () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _PaginationButton(
                                  icon: Icons.chevron_right,
                                  isEnabled: (_currentPage + 1) * _pageSize < _filteredMarks.length,
                                  onTap: () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  },
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
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
              ],
            ),
      // FAB for edit
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/mark-entry', arguments: _exam);
          if (result == true) {
            setState(() {
              _isLoading = true;
            });
            _loadMarks(forceRefresh: true);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.edit),
        label: const Text('Edit Marks'),
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
              _HeaderMeta(label: 'DATE', value: _formatExamDate(_exam!['exam_date'])),
              _HeaderMeta(label: 'TOTAL MARKS', value: '$totalMarks Marks'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderMeta(label: 'SCHOOL', value: _parseMeta(_exam!['for_school'], 'school')),
              _HeaderMeta(label: 'CLASS / SECTION', value: '${_parseMeta(_exam!['for_class'], 'class')} / ${_parseMeta(_exam!['for_section'], 'section')}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderMeta(label: 'TOPICS', value: _exam!['topic'] ?? 'Atomic Structure, Chemical Bonding'),
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
          _ActionChip(
            icon: Icons.description_outlined,
            label: 'Attendance PDF',
            onTap: () async {
              final url = _exam!['attendance_pdf_url'] as String? ?? '';
              if (url.isNotEmpty) {
                try {
                  final uri = Uri.parse(url);
                  final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not launch URL: $url'), backgroundColor: AppColors.errorText),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error launching URL: $e'), backgroundColor: AppColors.errorText),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No Attendance PDF URL found.'), backgroundColor: AppColors.errorText),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.quiz_outlined,
            label: 'Question Paper',
            onTap: () async {
              final url = _exam!['question_pdf_url'] as String? ?? '';
              if (url.isNotEmpty) {
                try {
                  final uri = Uri.parse(url);
                  final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not launch URL: $url'), backgroundColor: AppColors.errorText),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error launching URL: $e'), backgroundColor: AppColors.errorText),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No Question Paper URL found.'), backgroundColor: AppColors.errorText),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.download_outlined,
            label: 'Results',
            onTap: _showDownloadSheet,
          ),
          const SizedBox(width: 8),
          _ActionChip(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exam marked as soft-deleted.'), backgroundColor: AppColors.errorText),
                        );
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
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.outlineFaint)),
      ),
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
                    text: TextSpan(children: [
                      TextSpan(text: '${marksObtained?.toInt() ?? 0}', style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                      TextSpan(text: '/$totalMarks', style: AppTextStyles.labelXs.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.cardSurface, borderRadius: BorderRadius.circular(9999)),
      child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, letterSpacing: 1, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.filled = false, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.textMain;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(9999),
          border: filled ? null : Border.all(color: color?.withValues(alpha: 0.2) ?? AppColors.outlineLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? AppColors.onPrimary : activeColor),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.labelXs.copyWith(color: filled ? AppColors.onPrimary : activeColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Helper to format date from 'YYYY-MM-DD' to 'd MMM yyyy' (e.g. '29 May 2026')
String _formatExamDate(String? dateStr) {
  if (dateStr == null || dateStr.trim().isEmpty) return 'N/A';
  try {
    final parsedDate = DateTime.parse(dateStr.trim());
    return DateFormat('d MMM yyyy').format(parsedDate);
  } catch (e) {
    return dateStr;
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
            border: isEnabled ? null : Border.all(color: AppColors.outlineLight),
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
