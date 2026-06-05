import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/arms_snackbar.dart';

class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.filled = false,
  });
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
              label: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color ?? AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color ?? AppColors.textMain),
              label: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardSurface,
                foregroundColor: AppColors.textMain,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.val,
    required this.color,
    required this.icon,
  });
  final String title;
  final String val;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: color),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: AppTextStyles.headerSmall.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: color == AppColors.onSurfaceVariant ? AppColors.textMain : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.labelXsUppercase.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectProgressBar extends StatelessWidget {
  const SubjectProgressBar({
    super.key,
    required this.name,
    required this.val,
    required this.percent,
  });
  final String name;
  final double val;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: AppTextStyles.labelXs.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            Text(
              percent,
              style: AppTextStyles.labelXs.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
            value: val,
            minHeight: 8,
            backgroundColor: AppColors.outlineLight,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class ReportItem extends StatelessWidget {
  const ReportItem({
    super.key,
    required this.name,
    required this.size,
    required this.subject,
  });
  final String name;
  final String size;
  final String subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Icon(
            name.endsWith('.xlsx') ? Icons.table_chart : Icons.picture_as_pdf,
            color: name.endsWith('.xlsx') ? AppColors.successText : AppColors.errorText,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.labelXs.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$subject • $size',
                  style: AppTextStyles.labelXs.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.download,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: () {
              ArmsSnackbar.showSuccess(context, 'Downloaded $name successfully!');
            },
          ),
        ],
      ),
    );
  }
}
