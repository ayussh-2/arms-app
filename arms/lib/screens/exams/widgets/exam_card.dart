import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/services/exam_lookup_cache.dart';

class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
    required this.onDownloadReport,
  });

  final Map<String, dynamic> exam;
  final VoidCallback onTap;
  final VoidCallback onDownloadReport;

  String parseMeta(dynamic val, String type) {
    if (val == null) return 'All';
    final str = val.toString().trim();
    if (str.isEmpty || str == '[]' || str == 'null') return 'All';

    // Clean up bracket characters and quotes if any
    final clean = str
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", "")
        .trim();
    if (clean.isEmpty) return 'All';

    // Handle comma-separated UUID list if any
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

  @override
  Widget build(BuildContext context) {
    final isSaved = exam['mark_saved'] == true;
    final subjects = exam['subjects'] as List? ?? [];
    final subjectNames = subjects.map((s) => s['name'] ?? '').join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam['name'] ?? '',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjectNames.toUpperCase(),
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
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
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.outlineLight, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetaItem(
                          icon: Icons.school_outlined,
                          text: '${parseMeta(exam['for_school'], 'school')} | ${parseMeta(exam['for_class'], 'class')} | ${parseMeta(exam['for_section'], 'section')}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MetaItem(
                        icon: Icons.event_outlined,
                        text: AppDateUtils.formatToDMY(DateTime.tryParse(exam['exam_date'] ?? '') ?? DateTime.now()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MetaItem(
                        icon: Icons.assignment_outlined,
                        text: 'Total Marks: ${exam['total_marks'] ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: onDownloadReport,
                      icon: const Icon(
                        Icons.download,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'Download Report',
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
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
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.labelXs.copyWith(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
