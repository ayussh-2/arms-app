import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_student_row.dart';
import '../../widgets/arms_sticky_footer.dart';

/// Attendance feed/marking screen matching attendance-sheet.html.
/// Fetches student roster and allows marking P/A for each student.
class AttendanceFeedScreen extends StatefulWidget {
  const AttendanceFeedScreen({super.key});

  @override
  State<AttendanceFeedScreen> createState() => _AttendanceFeedScreenState();
}

class _AttendanceFeedScreenState extends State<AttendanceFeedScreen> {
  late String _classId;
  late String _sectionId;
  late String _date;
  late String _sessionKey;
  late String _title;

  List<Map<String, dynamic>> _students = [];
  final Map<String, AttendanceStatus> _statuses = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // For undo support
  Map<String, AttendanceStatus>? _lastBulkSnapshot;

  int get _presentCount => _statuses.values.where((s) => s == AttendanceStatus.present).length;
  int get _absentCount => _statuses.values.where((s) => s == AttendanceStatus.absent).length;
  int get _unmarkedCount => _statuses.values.where((s) => s == AttendanceStatus.unmarked).length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _isLoading) {
      _classId = args['classId'] as String;
      _sectionId = args['sectionId'] as String;
      _date = args['date'] as String;
      _sessionKey = args['sessionKey'] as String;
      _title = args['title'] as String;
      _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getStudents),
        variables: {'classId': _classId, 'sectionId': _sectionId},
      ));

      if (!mounted) return;
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load students: ${result.exception.toString()}'), backgroundColor: AppColors.errorText),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final list = (result.data?['students'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _students = list;
        for (final s in list) {
          _statuses[s['id']] = AttendanceStatus.unmarked;
        }
        _isLoading = false;
      });
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

  void _setAllStatus(AttendanceStatus status) {
    setState(() {
      _lastBulkSnapshot = Map.from(_statuses);
      for (final key in _statuses.keys) {
        if (_statuses[key] == AttendanceStatus.unmarked) {
          _statuses[key] = status;
        }
      }
    });
  }

  void _undoBulk() {
    if (_lastBulkSnapshot != null) {
      setState(() {
        _statuses.clear();
        _statuses.addAll(_lastBulkSnapshot!);
        _lastBulkSnapshot = null;
      });
    }
  }

  Future<void> _save() async {
    final client = GraphQLProvider.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Check for unmarked students
    if (_unmarkedCount > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
            side: BorderSide(color: AppColors.outlineLight),
          ),
          title: Text('Unmarked Students', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700)),
          content: Text('You have $_unmarkedCount unmarked student(s). Save them as absent?', style: AppTextStyles.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.onSurfaceVariant),
              child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text('Save', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      // Mark unmarked as absent
      for (final key in _statuses.keys) {
        if (_statuses[key] == AttendanceStatus.unmarked) {
          _statuses[key] = AttendanceStatus.absent;
        }
      }
    }

    setState(() => _isSaving = true);

    final input = _students.map((s) {
      final id = s['id'] as String;
      final isPresent = _statuses[id] == AttendanceStatus.present;
      final statusStr = isPresent ? 'present' : 'absent';
      return {
        'student_id': id,
        'attendance_date': _date,
        '${_sessionKey}_status': statusStr,
        'admin_id': 'admin-001',
      };
    }).toList();

    try {
      await client.mutate(MutationOptions(
        document: gql(GqlQueries.saveAttendance),
        variables: {'input': input},
      ));

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully'), backgroundColor: AppColors.successText),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                // Student list
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 0, AppSpacing.marginPage, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Header
                          Text(_title, style: AppTextStyles.displayMobile),
                          const SizedBox(height: 4),
                          Text(_date, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: AppSpacing.stackLg),

                          // Bulk actions
                          Text('BULK ACTIONS', style: AppTextStyles.labelXsUppercase),
                          const SizedBox(height: AppSpacing.stackSm),
                          Row(
                            children: [
                              _BulkButton(label: 'All Present', onTap: () => _setAllStatus(AttendanceStatus.present)),
                              const SizedBox(width: 8),
                              _BulkButton(label: 'All Absent', onTap: () => _setAllStatus(AttendanceStatus.absent)),
                              const SizedBox(width: 8),
                              _BulkButton(label: 'Undo', icon: Icons.undo, onTap: _lastBulkSnapshot != null ? _undoBulk : null),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 0, AppSpacing.marginPage, 200),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final s = _students[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ArmsStudentRow(
                                studentName: s['name'] ?? '',
                                rollNo: 'Roll ${s['roll_no'] ?? ''}',
                                avatarUrl: s['image_url'],
                                status: _statuses[s['id']] ?? AttendanceStatus.unmarked,
                                onStatusChanged: (status) => setState(() => _statuses[s['id']] = status),
                              ),
                            );
                          },
                          childCount: _students.length,
                        ),
                      ),
                    ),
                  ],
                ),

                // Sticky footer
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ArmsStickyFooter(
                    summaryWidget: _buildSummary(),
                    primaryButtonText: _isSaving ? 'Saving...' : 'Save',
                    onPrimaryPressed: _isSaving ? () {} : _save,
                    secondaryButtonText: 'Show Absentees',
                    onSecondaryPressed: () {},
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        _SummaryItem(label: 'PRESENT', value: '$_presentCount', color: AppColors.successText),
        const SizedBox(width: 24),
        _SummaryItem(label: 'ABSENT', value: '$_absentCount', color: AppColors.errorText),
        const SizedBox(width: 24),
        _SummaryItem(label: 'UNMARKED', value: '$_unmarkedCount', color: AppColors.textMain),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelXsUppercase),
        Text(value, style: AppTextStyles.headerSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _BulkButton extends StatelessWidget {
  const _BulkButton({required this.label, this.icon, required this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: onTap != null ? AppColors.outline.withValues(alpha: 0.5) : AppColors.outline.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: AppColors.onSurfaceVariant), const SizedBox(width: 4)],
          Text(label, style: AppTextStyles.labelXs.copyWith(fontWeight: FontWeight.w600, color: onTap != null ? AppColors.onSurfaceVariant : AppColors.outline)),
        ],
      ),
    );
  }
}
