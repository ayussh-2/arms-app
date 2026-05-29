import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_student_row.dart';
import '../../widgets/arms_sticky_footer.dart';
import '../../core/auth/auth_service.dart';
import '../../core/utils/image_url_helper.dart';

/// Attendance feed/marking screen matching attendance-sheet.html.
/// Fetches student roster and allows marking P/A for each student.
class AttendanceFeedScreen extends StatefulWidget {
  const AttendanceFeedScreen({super.key});

  @override
  State<AttendanceFeedScreen> createState() => _AttendanceFeedScreenState();
}

class _AttendanceFeedScreenState extends State<AttendanceFeedScreen> {
  late String _schoolId;
  late String _schoolName;
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

  String get _formattedDate {
    try {
      final parsed = DateTime.parse(_date);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return _date;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _isLoading) {
      _schoolId = args['schoolId'] as String;
      _schoolName = args['schoolName'] as String? ?? '';
      _classId = args['classId'] as String;
      _sectionId = args['sectionId'] as String;
      _date = args['date'] as String;
      _sessionKey = args['sessionKey'] as String;
      _title = args['title'] as String;
      _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    final orgId = AuthService.currentAdmin?.organization?.id;
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organization associated with this account.'), backgroundColor: AppColors.errorText),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(QueryOptions(
        document: gql(GqlQueries.getStudentsForAttendance),
        variables: {
          'organisationId': orgId,
          'attendanceDate': _date,
          'attendanceSession': _sessionKey,
          'classId': _classId,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      )).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Query timed out after 10s'),
      );

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

      final list = (result.data?['getStudentsForAttendance'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _students = list;
        for (final row in list) {
          final student = row['student'] as Map<String, dynamic>;
          final sId = student['id'] as String;
          final statusStr = row['status'] as String?;
          
          AttendanceStatus initialStatus = AttendanceStatus.unmarked;
          if (statusStr == 'present') {
            initialStatus = AttendanceStatus.present;
          } else if (statusStr == 'absent') {
            initialStatus = AttendanceStatus.absent;
          }
          _statuses[sId] = initialStatus;
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

    final orgId = AuthService.currentAdmin?.organization?.id;
    final adminId = AuthService.currentAdmin?.id;
    if (orgId == null || adminId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error: No active admin session found.'), backgroundColor: AppColors.errorText),
      );
      setState(() => _isSaving = false);
      return;
    }

    final updates = _students.map((s) {
      final student = s['student'] as Map<String, dynamic>;
      final id = student['id'] as String;
      final isPresent = _statuses[id] == AttendanceStatus.present;
      final statusStr = isPresent ? 'present' : 'absent';
      return {
        'studentId': id,
        'status': statusStr,
      };
    }).toList();

    try {
      final result = await client.mutate(MutationOptions(
        document: gql(GqlQueries.saveAttendance),
        variables: {
          'organisationId': orgId,
          'adminId': adminId,
          'attendanceDate': _date,
          'attendanceSession': _sessionKey,
          'updates': updates,
        },
      ));

      if (result.hasException) {
        throw result.exception!;
      }

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

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  void _showAbsentees() {
    final absentees = _students.where((s) {
      final student = s['student'] as Map<String, dynamic>;
      final studentId = student['id'] as String;
      return _statuses[studentId] == AttendanceStatus.absent;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Absent Students (${absentees.length})',
                    style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (absentees.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No students marked as absent',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: absentees.length,
                    itemBuilder: (_, i) {
                      final s = absentees[i];
                      final student = s['student'] as Map<String, dynamic>;
                      final initials = _getInitials(student['name'] ?? '');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: student['image_url'] != null && (student['image_url'] as String).isNotEmpty
                              ? NetworkImage(ImageUrlHelper.sanitizeUrl(student['image_url'])!)
                              : null,
                          child: student['image_url'] == null || (student['image_url'] as String).isEmpty
                              ? Text(
                                  initials,
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(student['name'] ?? '', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text('Roll ${student['roll_no'] ?? ''}', style: AppTextStyles.labelXs),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
                          if (_schoolName.isNotEmpty) ...[
                            Text(
                              _schoolName.toUpperCase(),
                              style: AppTextStyles.labelXsUppercase.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(_title, style: AppTextStyles.displayMobile),
                          const SizedBox(height: 4),
                          Text(_formattedDate, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
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
                            final student = s['student'] as Map<String, dynamic>;
                            final studentId = student['id'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ArmsStudentRow(
                                studentName: student['name'] ?? '',
                                rollNo: 'Roll ${student['roll_no'] ?? ''}',
                                avatarUrl: student['image_url'],
                                status: _statuses[studentId] ?? AttendanceStatus.unmarked,
                                onStatusChanged: (status) => setState(() => _statuses[studentId] = status),
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
                    onPrimaryPressed: (_isSaving || _unmarkedCount > 0) ? null : _save,
                    secondaryButtonText: 'Show Absentees',
                    onSecondaryPressed: _showAbsentees,
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
