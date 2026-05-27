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

  String downloadSelection = 'All students';
  String downloadFormat = 'PDF Format';

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

  String _parseMeta(dynamic val, String type) {
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
                          color: AppColors.outline.withOpacity(0.3),
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
            color: isSelected ? AppColors.primary : AppColors.outline.withOpacity(0.3),
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
    final subjectNames = subjects.map((s) => s['subject']?['name'] ?? '').join(', ');
    final totalMarks = _exam!['total_marks'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        title: 'Exam Details',
        showBackButton: true,
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
                const SizedBox(height: 120),
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
          Container(height: 1, color: AppColors.outline.withOpacity(0.15)),
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
            filled: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading Attendance PDF...'), backgroundColor: AppColors.primary),
              );
            },
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.quiz_outlined,
            label: 'Question Paper',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Question Paper...')),
              );
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
        border: Border(bottom: BorderSide(color: AppColors.outline.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text((index + 1).toString().padLeft(2, '0'), style: AppTextStyles.labelXs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] ?? '', style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMain)),
                Text('Roll: #${student['roll_no'] ?? ''}', style: AppTextStyles.labelXs.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant)),
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
          border: filled ? null : Border.all(color: color?.withOpacity(0.2) ?? AppColors.outline.withOpacity(0.15)),
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
