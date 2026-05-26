import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
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

  Future<void> _loadMarks() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GqlQueries.getMarks),
      variables: {'examId': _exam!['id']},
    ));
    if (!mounted) return;
    final list = (result.data?['marks'] as List? ?? []).cast<Map<String, dynamic>>();
    setState(() {
      _marks = list;
      _filteredMarks = list;
      _isLoading = false;
    });
  }

  void _filterMarks() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    if (_exam == null) {
      return const Scaffold(body: Center(child: Text('No exam data')));
    }

    final subjects = _exam!['subjects'] as List? ?? [];
    final subjectNames = subjects.map((s) => s['subject']?['name'] ?? '').join(', ');
    final totalMarks = _exam!['total_marks'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ArmsTopAppBar(
        title: 'Exam Details',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textMain),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage),
              children: [
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
                    const Spacer(),
                    _iconBtn(Icons.filter_list),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.sort),
                  ],
                ),
                const SizedBox(height: AppSpacing.stackMd),
                ArmsInputField(controller: _searchCtrl, hintText: 'Search students...', prefixIcon: Icons.search),
                const SizedBox(height: AppSpacing.stackMd),
                // Table header
                _buildTableHeader(),
                // Rows
                ...List.generate(_filteredMarks.length, (i) => _buildMarkRow(i, _filteredMarks[i], totalMarks)),
                const SizedBox(height: 100),
              ],
            ),
      // FAB for edit
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/mark-entry', arguments: _exam),
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
      decoration: BoxDecoration(color: AppColors.cardSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXAM TITLE', style: AppTextStyles.labelXsUppercase),
          const SizedBox(height: 4),
          Text(_exam!['name'] ?? '', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subjectNames, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.outline.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderMeta(label: 'DATE', value: _exam!['exam_date'] ?? 'N/A'),
              _HeaderMeta(label: 'TOTAL MARKS', value: '$totalMarks Marks'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderMeta(label: 'SCHOOL', value: _exam!['for_school'] ?? 'All'),
              _HeaderMeta(label: 'CLASS / SECTION', value: '${_exam!['for_class'] ?? 'All'} / ${_exam!['for_section'] ?? 'All'}'),
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
          _ActionChip(icon: Icons.description_outlined, label: 'Attendance PDF', filled: true, onTap: () {}),
          const SizedBox(width: 8),
          _ActionChip(icon: Icons.quiz_outlined, label: 'Question Paper', onTap: () {}),
          const SizedBox(width: 8),
          _ActionChip(icon: Icons.download_outlined, label: 'Results', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final style = AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, letterSpacing: 1.5);
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
        border: Border(bottom: BorderSide(color: AppColors.outline.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('${(index + 1).toString().padLeft(2, '0')}', style: AppTextStyles.labelXs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] ?? '', style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain)),
                Text('Roll: #${student['roll_no'] ?? ''}', style: AppTextStyles.labelXs.copyWith(fontSize: 12)),
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
                      TextSpan(text: '${marksObtained?.toInt() ?? 0}', style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent)),
                      TextSpan(text: '/$totalMarks', style: AppTextStyles.labelXs.copyWith(fontSize: 12)),
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
          Text(label, style: AppTextStyles.labelXsUppercase.copyWith(fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w500, color: AppColors.textMain)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(9999),
          border: filled ? null : Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? AppColors.onPrimary : AppColors.textMain),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.labelXs.copyWith(color: filled ? AppColors.onPrimary : AppColors.textMain)),
          ],
        ),
      ),
    );
  }
}
