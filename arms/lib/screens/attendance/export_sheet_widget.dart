import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/graphql/queries.dart';
import '../../widgets/arms_dropdown_selector.dart';

/// Interactive Export Sheet screen built exactly from export-sheet.html.
/// Supports date range picking, template selecting, dynamic class fetching, and premium configuration toggles.
class ExportSheetWidget extends StatefulWidget {
  const ExportSheetWidget({super.key});

  @override
  State<ExportSheetWidget> createState() => _ExportSheetWidgetState();
}

class _ExportSheetWidgetState extends State<ExportSheetWidget> {
  String _selectedTemplate = 'Monthly Detailed Report';
  String _selectedSession = 'Morning';

  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSectionId;
  String? _selectedSectionName;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  bool _includePhoto = false;
  bool _showHolidays = true;
  bool _showSundays = false;
  bool _dateAscending = true;
  bool _alternateShading = true;

  bool _isGenerating = false;
  String? _generationType; // 'preview', 'excel', 'pdf'

  final List<String> _templates = [
    'Monthly Detailed Report',
    'Weekly Summary',
    'Daily Log',
  ];

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _showClassPicker() async {
    final client = GraphQLProvider.of(context).value;
    final cResult = await client.query(QueryOptions(document: gql(GqlQueries.getClasses)));
    final sResult = await client.query(QueryOptions(document: gql(GqlQueries.getSections)));
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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

  void _showTemplatePicker() {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Report Template', style: AppTextStyles.headerSmall),
            const SizedBox(height: 8),
            Column(
              children: _templates.map((t) {
                return ListTile(
                  title: Text(t, style: AppTextStyles.bodyMedium),
                  trailing: _selectedTemplate == t
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedTemplate = t);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _triggerGeneration(String type) {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Class & Section first.'),
          backgroundColor: AppColors.errorText,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationType = type;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generationType = null;
      });

      String msg = '';
      if (type == 'preview') {
        msg = 'Sheet preview generated successfully for $_selectedClassName!';
        _showPreviewDialog();
      } else if (type == 'excel') {
        msg = 'Excel spreadsheet exported successfully!';
      } else {
        msg = 'PDF document exported successfully!';
      }

      if (type != 'preview') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.successText,
          ),
        );
      }
    });
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sheet Preview', style: AppTextStyles.headerSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewRow('Template', _selectedTemplate),
            _previewRow('Class & Section', '$_selectedClassName - $_selectedSectionName'),
            _previewRow('Date Range', '${_formatDate(_startDate)} to ${_formatDate(_endDate)}'),
            _previewRow('Session', _selectedSession),
            const Divider(height: 24),
            _previewRow('Photo Option', _includePhoto ? 'Included' : 'Excluded'),
            _previewRow('Holidays Visible', _showHolidays ? 'Yes' : 'No'),
            _previewRow('Sundays Visible', _showSundays ? 'Yes' : 'No'),
            _previewRow('Ordering', _dateAscending ? 'Ascending' : 'Descending'),
            _previewRow('Row Shading', _alternateShading ? 'On' : 'Off'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMain),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classDisplay = _selectedClassId != null ? '$_selectedClassName - $_selectedSectionName' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Template Selector Card
        _sectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT TEMPLATE',
                style: AppTextStyles.labelXs.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ArmsDropdownSelector(
                value: _selectedTemplate,
                icon: Icons.description_outlined,
                onTap: _showTemplatePicker,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutterCard),

        // Configuration Card
        _sectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONFIGURATION',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Class Section selector
              Text(
                'CLASS/SECTION',
                style: AppTextStyles.labelXs.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ArmsDropdownSelector(
                value: classDisplay,
                placeholder: 'Select Class/Section',
                icon: Icons.class_outlined,
                onTap: _showClassPicker,
              ),
              const SizedBox(height: 16),

              // Date pickers stacked vertically (flex-col)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START DATE',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ArmsDropdownSelector(
                    value: _formatDate(_startDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickDate(true),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'END DATE',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ArmsDropdownSelector(
                    value: _formatDate(_endDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickDate(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Session switcher
              Text(
                'SESSIONS',
                style: AppTextStyles.labelXs.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    _sessionButton('Morning'),
                    _sessionButton('Evening'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutterCard),

        // Display Toggles Card
        _sectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DISPLAY OPTIONS',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              _toggleRow('Include Student Photo', _includePhoto, (v) => setState(() => _includePhoto = v)),
              _toggleRow('Show Holidays', _showHolidays, (v) => setState(() => _showHolidays = v)),
              _toggleRow('Show Sundays', _showSundays, (v) => setState(() => _showSundays = v)),
              _toggleRow('Date Order (Ascending)', _dateAscending, (v) => setState(() => _dateAscending = v)),
              _toggleRow('Alternate Row Shading', _alternateShading, (v) => setState(() => _alternateShading = v)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutterCard),

        // Action Buttons Section
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Preview Sheet',
                      icon: Icons.visibility_outlined,
                      type: 'preview',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      label: 'Export Excel',
                      icon: Icons.table_view_outlined,
                      type: 'excel',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : () => _triggerGeneration('pdf'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: _isGenerating && _generationType == 'pdf'
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Generate Sheet',
                              style: AppTextStyles.headerSmall.copyWith(
                                color: AppColors.onPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.marginPage),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sessionButton(String name) {
    final isSelected = _selectedSession == name;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSession = name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Center(
            child: Text(
              name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(String title, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
          Switch.adaptive(
            value: val,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required IconData icon, required String type}) {
    final active = _isGenerating && _generationType == type;

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: _isGenerating ? null : () => _triggerGeneration(type),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          backgroundColor: AppColors.primary.withOpacity(0.04),
          foregroundColor: AppColors.primary,
        ),
        child: active
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
