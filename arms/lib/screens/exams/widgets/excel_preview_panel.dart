import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ExcelPreviewPanel extends StatefulWidget {
  final Map<String, dynamic> excelPreview;
  final List<Map<String, dynamic>> subjects;

  const ExcelPreviewPanel({
    super.key,
    required this.excelPreview,
    required this.subjects,
  });

  @override
  State<ExcelPreviewPanel> createState() => _ExcelPreviewPanelState();
}

class _ExcelPreviewPanelState extends State<ExcelPreviewPanel> {
  bool _showMissingRows = false;
  bool _showExtraRows = false;

  @override
  Widget build(BuildContext context) {
    final requiredRows = widget.excelPreview['requiredRows'] as int;
    final derivedRows = widget.excelPreview['derivedRows'] as int;
    final missingRows = widget.excelPreview['missingRows'] as List<dynamic>;
    final extraRows = widget.excelPreview['extraRows'] as List<dynamic>;
    final parsedMarks = widget.excelPreview['parsedMarks'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatCard(
              'REQUIRED',
              requiredRows.toString(),
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.1),
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'DERIVED',
              derivedRows.toString(),
              AppColors.successText,
              AppColors.successBg,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'MISSING',
              missingRows.length.toString(),
              AppColors.accent,
              AppColors.cardSurface,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'EXTRA',
              extraRows.length.toString(),
              AppColors.errorText,
              AppColors.errorBg,
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (missingRows.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() => _showMissingRows = !_showMissingRows),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Students missing from Excel (${missingRows.length})',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _showMissingRows ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                    ],
                  ),
                  if (_showMissingRows) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 4),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: missingRows.length,
                      itemBuilder: (ctx, idx) {
                        final r = missingRows[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record, size: 8, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r['name'] ?? '',
                                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                                ),
                              ),
                              Text(
                                'Roll No: ${r['rollNo']}',
                                style: AppTextStyles.labelXs.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (extraRows.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() => _showExtraRows = !_showExtraRows),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.errorBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorText.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.errorText, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Extra rows found in Excel (${extraRows.length}) - will be ignored',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.errorText,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _showExtraRows ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.errorText,
                      ),
                    ],
                  ),
                  if (_showExtraRows) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 4),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: extraRows.length,
                      itemBuilder: (ctx, idx) {
                        final r = extraRows[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record, size: 8, color: AppColors.errorText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r['name'] ?? 'Unknown Name',
                                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, color: AppColors.errorText),
                                ),
                              ),
                              Text(
                                'Roll No: ${r['rollNo']}',
                                style: AppTextStyles.labelXs.copyWith(fontSize: 11, color: AppColors.errorText),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Matched Student Scores Preview'.toUpperCase(),
          style: AppTextStyles.labelXsUppercase.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.cardSurface),
                columns: [
                  const DataColumn(
                    label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const DataColumn(
                    label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  ...widget.subjects.map(
                    (sub) => DataColumn(
                      label: Text(
                        '${sub['name']}\n(Max: ${sub['max_marks']})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
                rows: parsedMarks.map((studentRow) {
                  final rollNo = studentRow['rollNo'] as String;
                  final name = studentRow['name'] as String;
                  final marksMap = studentRow['marks'] as Map<String, String>;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(rollNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      DataCell(
                        Text(name, style: const TextStyle(fontSize: 12)),
                      ),
                      ...widget.subjects.map((sub) {
                        final subId = sub['id'] as String;
                        final score = marksMap[subId] ?? '—';
                        return DataCell(
                          Center(
                            child: Text(
                              score,
                              style: TextStyle(
                                fontWeight: score == '—' ? FontWeight.normal : FontWeight.bold,
                                color: score == '—' ? AppColors.textSecondary : AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
