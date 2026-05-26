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
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(
      QueryOptions(document: gql(GqlQueries.getExams)),
    );
    if (!mounted) return;
    final list = (result.data?['exams'] as List? ?? []).cast<Map<String, dynamic>>();
    setState(() {
      _allExams = list;
      _filteredExams = list;
      _isLoading = false;
    });
  }

  void _filterExams() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredExams = _allExams;
      } else {
        _filteredExams = _allExams.where((e) {
          final name = (e['name'] as String? ?? '').toLowerCase();
          final series = (e['series']?['name'] as String? ?? '').toLowerCase();
          return name.contains(q) || series.contains(q);
        }).toList();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // Search + filters
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, AppSpacing.stackMd, AppSpacing.marginPage, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ArmsInputField(controller: _searchController, hintText: 'Search exams...', prefixIcon: Icons.search),
                        const SizedBox(height: AppSpacing.stackMd),
                      ],
                    ),
                  ),
                ),
                // Exam list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
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
                              child: _ExamCard(exam: _filteredExams[i], onTap: () => _showActionSheet(_filteredExams[i])),
                            ),
                            childCount: _filteredExams.length,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Individual exam card matching exam-list.html design.
class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap});
  final Map<String, dynamic> exam;
  final VoidCallback onTap;

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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
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
                      Text(exam['name'] ?? '', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subjectNames, style: AppTextStyles.labelXs.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
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
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.surfaceVariant, width: 1))),
              child: Column(
                children: [
                  Row(
                    children: [
                      _MetaItem(icon: Icons.school_outlined, text: '${exam['for_school'] ?? 'All'} | ${exam['for_class'] ?? 'All'} | ${exam['for_section'] ?? 'All'}'),
                      const Spacer(),
                      _MetaItem(icon: Icons.event_outlined, text: exam['exam_date'] ?? ''),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MetaItem(icon: Icons.assignment_outlined, text: 'Total Marks: ${exam['total_marks'] ?? 0}'),
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
        Text(text, style: AppTextStyles.labelXs.copyWith(fontSize: 13)),
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
