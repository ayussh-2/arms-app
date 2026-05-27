import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_top_app_bar.dart';
import '../../widgets/arms_segmented_control.dart';
import '../../widgets/arms_dropdown_selector.dart';
import 'leave_management_screen.dart';
import 'export_sheet_widget.dart';

class AttendanceConfigScreen extends StatefulWidget {
  const AttendanceConfigScreen({super.key});

  @override
  State<AttendanceConfigScreen> createState() => _AttendanceConfigScreenState();
}

class _AttendanceConfigScreenState extends State<AttendanceConfigScreen> {
  int _tabIndex = 0;
  DateTime _selectedDate = DateTime.now();
  int _selectedSession = 0;
  int _refreshKey = 0;
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSectionId;
  String? _selectedSectionName;

  static const _sessions = [
    'Morning In',
    'Morning Out',
    'Evening In',
    'Evening Out',
  ];

  bool get _canLoad => _selectedClassId != null && _selectedSectionId != null;

  String get _sessionKey {
    const keys = ['morning_in', 'morning_out', 'evening_in', 'evening_out'];
    return keys[_selectedSession];
  }

  bool get _isPastDate {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(_selectedDate).isBefore(today);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _showClassPicker() async {
    final client = GraphQLProvider.of(context).value;
    final results = await Future.wait([
      client.query(QueryOptions(document: gql(GqlQueries.getClasses))),
      client.query(QueryOptions(document: gql(GqlQueries.getSections))),
    ]);
    final cResult = results[0];
    final sResult = results[1];
    if (!mounted) return;

    final classes = cResult.data?['classes'] as List? ?? [];
    final sections = sResult.data?['sections'] as List? ?? [];
    final opts = <Map<String, String>>[];
    for (final c in classes) {
      for (final s in sections) {
        opts.add({
          'label': '${c['name']} - ${s['name']}',
          'cId': c['id'],
          'cName': c['name'],
          'sId': s['id'],
          'sName': s['name'],
        });
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Select Class & Section', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(opts[i]['label']!, style: AppTextStyles.bodyMedium),
                  onTap: () {
                    setState(() {
                      _selectedClassId = opts[i]['cId'];
                      _selectedClassName = opts[i]['cName'];
                      _selectedSectionId = opts[i]['sId'];
                      _selectedSectionName = opts[i]['sName'];
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadRoster() {
    if (!_canLoad) return;
    Navigator.of(context).pushNamed('/attendance-feed', arguments: {
      'classId': _selectedClassId,
      'sectionId': _selectedSectionId,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'sessionKey': _sessionKey,
      'title': '$_selectedClassName - $_selectedSectionName',
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(_selectedDate);
    final classDisplay = _selectedClassId != null ? '$_selectedClassName - $_selectedSectionName' : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(showBackButton: true),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          if (_tabIndex == 1) {
            setState(() {
              _refreshKey++;
            });
            await Future.delayed(const Duration(milliseconds: 600));
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginPage, vertical: AppSpacing.stackMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('Attendance', style: AppTextStyles.displayLarge),
            const SizedBox(height: AppSpacing.stackLg),
            ArmsSegmentedControl(options: const ['Feed', 'Leave', 'Sheet'], selectedIndex: _tabIndex, onChanged: (i) => setState(() => _tabIndex = i)),
            const SizedBox(height: AppSpacing.stackLg),
            if (_tabIndex == 0) ..._buildFeedTab(dateStr, classDisplay),
            if (_tabIndex == 1) LeaveManagementWidget(key: ValueKey(_refreshKey)),
            if (_tabIndex == 2) const ExportSheetWidget(),
          ],
        ),
      ),
      ),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/leave-apply');
                if (result == true) {
                  setState(() {
                    _refreshKey++;
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

  List<Widget> _buildFeedTab(String dateStr, String? classDisplay) {
    return [
      ArmsDropdownSelector(label: 'Date', value: dateStr, icon: Icons.calendar_today_outlined, onTap: _pickDate),
      if (_isPastDate) Padding(padding: const EdgeInsets.only(left: 16, top: 4), child: Text('Warning: Selecting a past date.', style: AppTextStyles.labelXs.copyWith(color: AppColors.errorText, fontSize: 13))),
      const SizedBox(height: AppSpacing.stackLg),
      Padding(padding: const EdgeInsets.only(left: 16, bottom: 8), child: Text('Session', style: AppTextStyles.labelXs.copyWith(color: AppColors.textMain, fontWeight: FontWeight.w600))),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.2),
        itemCount: _sessions.length,
        itemBuilder: (_, i) => _SessionChip(label: _sessions[i], isSelected: _selectedSession == i, onTap: () => setState(() => _selectedSession = i)),
      ),
      const SizedBox(height: AppSpacing.stackLg),
      ArmsDropdownSelector(label: 'Class & Section', value: classDisplay, placeholder: 'Select Class/Section', onTap: _showClassPicker),
      const SizedBox(height: AppSpacing.stackLg),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _canLoad ? _loadRoster : null,
          style: ElevatedButton.styleFrom(backgroundColor: _canLoad ? AppColors.primary : AppColors.cardSurface, foregroundColor: _canLoad ? AppColors.onPrimary : AppColors.textSecondary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.roundFull))),
          child: Text('List Students', style: AppTextStyles.headerSmall.copyWith(color: _canLoad ? AppColors.onPrimary : AppColors.textSecondary)),
        ),
      ),
    ];
  }

  Widget _placeholder(String t, IconData ic) => Padding(padding: const EdgeInsets.only(top: 48), child: Center(child: Column(children: [Icon(ic, size: 64, color: AppColors.outline), const SizedBox(height: 16), Text(t, style: AppTextStyles.headerSmall), const SizedBox(height: 8), Text('Coming soon', style: AppTextStyles.labelXs)])));

  String _formatDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final today = DateUtils.dateOnly(DateTime.now());
    final prefix = DateUtils.dateOnly(d) == today ? 'Today, ' : '';
    return '$prefix${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.roundFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineMediumLight,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
      ),
    );
  }
}
