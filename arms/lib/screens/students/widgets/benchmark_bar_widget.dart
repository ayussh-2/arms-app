import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Compact inline exam benchmark visualization.
/// Shows student score progress bar with pins/markers for class average and class best/topper.
class BenchmarkBarWidget extends StatelessWidget {
  const BenchmarkBarWidget({
    super.key,
    required this.studentPercentage,
    this.bestPercentage,
    this.averagePercentage,
    this.showLabels = true,
  });

  final double? studentPercentage;
  final double? bestPercentage;
  final double? averagePercentage;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final sPct = (studentPercentage ?? 0.0).clamp(0.0, 100.0);
    final aPct = averagePercentage?.clamp(0.0, 100.0);
    final bPct = bestPercentage?.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visual Bar with markers
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final studentWidth = (sPct / 100.0) * width;
            final avgOffset = aPct != null ? (aPct / 100.0) * width : null;
            final bestOffset = bPct != null ? (bPct / 100.0) * width : null;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Base track
                Container(
                  height: 10,
                  width: width,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),

                // Student Progress Fill
                Container(
                  height: 10,
                  width: studentWidth,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),

                // Class Average Pin/Marker
                if (avgOffset != null)
                  Positioned(
                    left: (avgOffset - 2).clamp(0.0, width - 4),
                    top: -3,
                    child: Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Class Best/Topper Pin/Marker
                if (bestOffset != null)
                  Positioned(
                    left: (bestOffset - 2).clamp(0.0, width - 4),
                    top: -3,
                    child: Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        if (showLabels) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(
                label: 'Student',
                value: studentPercentage != null ? '${studentPercentage!.toStringAsFixed(1)}%' : '-',
                color: AppColors.primary,
              ),
              if (averagePercentage != null)
                _buildBadge(
                  label: 'Class Avg',
                  value: '${averagePercentage!.toStringAsFixed(1)}%',
                  color: const Color(0xFFD97706),
                ),
              if (bestPercentage != null)
                _buildBadge(
                  label: 'Top',
                  value: '${bestPercentage!.toStringAsFixed(1)}%',
                  color: const Color(0xFF16A34A),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: AppTextStyles.labelXs.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelXs.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
      ],
    );
  }
}
