import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/scorecard_models.dart';

enum ChartType { bar, line }
enum ScorecardMetric { percentage, marks, rank }

/// Interactive scorecard chart widget supporting Bar and Line views,
/// metric toggles (Percentage, Marks, Rank), sticky Y-axis and smooth horizontal scrolling.
class ScorecardChartWidget extends StatefulWidget {
  const ScorecardChartWidget({
    super.key,
    required this.chartData,
    this.title,
    this.height = 240,
    this.backgroundColor,
    this.showBorder = true,
  });

  final ScorecardChartData chartData;
  final String? title;
  final double height;
  final Color? backgroundColor;
  final bool showBorder;

  @override
  State<ScorecardChartWidget> createState() => _ScorecardChartWidgetState();
}

class _ScorecardChartWidgetState extends State<ScorecardChartWidget> {
  ChartType _chartType = ChartType.bar;
  ScorecardMetric _metric = ScorecardMetric.percentage;

  static const Color studentColor = AppColors.primary;
  static const Color bestColor = Color(0xFF16A34A);
  static const Color avgColor = Color(0xFFD97706);

  List<ScorecardChartPoint> get _activePoints {
    switch (_metric) {
      case ScorecardMetric.percentage:
        return widget.chartData.percentage;
      case ScorecardMetric.marks:
        return widget.chartData.marks;
      case ScorecardMetric.rank:
        return widget.chartData.rank;
    }
  }

  double get _maxY {
    final points = _activePoints;
    if (points.isEmpty) return 100.0;

    switch (_metric) {
      case ScorecardMetric.percentage:
        return 100.0;
      case ScorecardMetric.marks:
        double maxM = 0;
        for (final p in points) {
          maxM = max(maxM, p.studentValue ?? 0);
          maxM = max(maxM, p.bestValue ?? 0);
          maxM = max(maxM, p.averageValue ?? 0);
        }
        if (maxM <= 0) return 100.0;
        // Round up to nice number
        final ceilTen = (maxM / 10).ceil() * 10.0;
        return ceilTen > 0 ? ceilTen : 100.0;
      case ScorecardMetric.rank:
        double maxR = 1;
        for (final p in points) {
          maxR = max(maxR, p.studentValue ?? 1);
          maxR = max(maxR, p.bestValue ?? 1);
          maxR = max(maxR, p.averageValue ?? 1);
        }
        return max(5.0, (maxR / 5).ceil() * 5.0);
    }
  }

  double get _minY {
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final points = _activePoints;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: widget.showBorder ? Border.all(color: AppColors.outlineLight) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & View Switches
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: AppTextStyles.headerSmall,
            ),
            const SizedBox(height: 12),
          ],

          // Controls Row: Chart Type and Metric Switches
          _buildControlsRow(),
          const SizedBox(height: 16),

          // Main Chart with Sticky Y-Axis
          if (points.isEmpty)
            SizedBox(
              height: widget.height,
              child: Center(
                child: Text(
                  'No chart data available for this selection',
                  style: AppTextStyles.labelXs,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: widget.height,
              child: Row(
                children: [
                  // Sticky Y-Axis
                  _buildStickyYAxis(),
                  const SizedBox(width: 8),

                  // Horizontally Scrollable Plot Area
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = 96.0;
                        final computedWidth = max(
                          constraints.maxWidth,
                          points.length * itemWidth,
                        );

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: computedWidth,
                            height: widget.height,
                            child: _chartType == ChartType.bar
                                ? _buildBarChart(points)
                                : _buildLineChart(points),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Legend
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Metric Switcher: Percentage, Marks, Rank
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetricButton(ScorecardMetric.percentage, '%'),
              _buildMetricButton(ScorecardMetric.marks, 'Marks'),
              _buildMetricButton(ScorecardMetric.rank, 'Rank'),
            ],
          ),
        ),

        // Chart Type Switcher: Bar vs Line
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypeIcon(ChartType.bar, Icons.bar_chart_rounded),
              _buildTypeIcon(ChartType.line, Icons.show_chart_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricButton(ScorecardMetric metric, String label) {
    final isSelected = _metric == metric;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _metric = metric;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelXs.copyWith(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(ChartType type, IconData icon) {
    final isSelected = _chartType == type;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _chartType = type;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStickyYAxis() {
    final maxY = _maxY;
    final minY = _minY;
    final step = (maxY - minY) / 4.0;
    
    // Invert Y-axis for rank so Rank 1 is at top!
    final labels = _metric == ScorecardMetric.rank
        ? [
            1.0,
            1.0 + step,
            1.0 + step * 2,
            1.0 + step * 3,
            maxY,
          ]
        : [
            maxY,
            maxY - step,
            maxY - step * 2,
            maxY - step * 3,
            minY,
          ];

    String formatLabel(double val) {
      if (_metric == ScorecardMetric.percentage) {
        return '${val.toInt()}%';
      } else if (_metric == ScorecardMetric.rank) {
        return '#${val.round()}';
      } else {
        return val >= 100 ? val.toInt().toString() : val.toStringAsFixed(0);
      }
    }

    return SizedBox(
      width: 42,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ...labels.map(
            (val) => Text(
              formatLabel(val),
              style: AppTextStyles.labelXs.copyWith(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24), // Offset for X-axis labels
        ],
      ),
    );
  }

  String _formatBarTopValue(double val) {
    if (_metric == ScorecardMetric.percentage) {
      final s = val.toStringAsFixed(2);
      if (s.endsWith('.00')) {
        return '${val.toInt()}%';
      } else if (s.endsWith('0')) {
        return '${val.toStringAsFixed(1)}%';
      }
      return '$s%';
    } else if (_metric == ScorecardMetric.rank) {
      return '#${val.toInt()}';
    } else {
      final s = val.toStringAsFixed(2);
      if (s.endsWith('.00')) {
        return '${val.toInt()}';
      } else if (s.endsWith('0')) {
        return val.toStringAsFixed(1);
      }
      return s;
    }
  }

  String _formatChartLabel(String label) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (regex.hasMatch(label)) {
      try {
        final d = DateTime.parse(label);
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final day = d.day.toString().padLeft(2, '0');
        final month = months[d.month - 1];
        final year = (d.year % 100).toString().padLeft(2, '0');
        return '$day $month $year';
      } catch (_) {}
    }
    return label.length > 9 ? '${label.substring(0, 8)}…' : label;
  }

  Widget _buildBarChart(List<ScorecardChartPoint> points) {
    final maxY = _maxY;

    // Helper to calculate visual rod height (Inverted for rank so rank 1 is highest)
    double calcVisualHeight(double? rawVal) {
      if (rawVal == null || rawVal <= 0) return 0.0;
      if (_metric == ScorecardMetric.rank) {
        // Rank 1 maps to maxY, rank maxY maps to 1.0 (inverted visual scale)
        return (maxY - rawVal + 1.0).clamp(1.0, maxY);
      }
      return rawVal.clamp(0.0, maxY);
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.25,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: max(1.0, maxY / 4),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.outlineLight,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final formatted = _formatChartLabel(points[index].label);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    formatted,
                    style: AppTextStyles.labelXs.copyWith(
                      fontSize: 10,
                      color: AppColors.textMain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 3,
            fitInsideHorizontally: false,
            fitInsideVertically: false,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (rod.toY <= 0) return null;
              final point = points[group.x.toInt()];
              double? actualVal;
              if (rodIndex == 0) {
                actualVal = point.studentValue;
              } else if (rodIndex == 1) {
                actualVal = point.bestValue;
              } else {
                actualVal = point.averageValue;
              }
              if (actualVal == null) return null;

              final valStr = _formatBarTopValue(actualVal);
              Color textColor;
              if (rodIndex == 0) {
                textColor = studentColor;
              } else if (rodIndex == 1) {
                textColor = bestColor;
              } else {
                textColor = avgColor;
              }

              final sVisual = calcVisualHeight(point.studentValue);
              final bVisual = calcVisualHeight(point.bestValue);
              final aVisual = calcVisualHeight(point.averageValue);

              // Stagger vertically if two adjacent rods are at the same or nearly identical level
              String displayText = valStr;
              if (rodIndex == 1) {
                // If Best is close to Student in height, lift Best up
                if (sVisual > 0 && (bVisual - sVisual).abs() < 9) {
                  displayText = '$valStr\n ';
                }
              } else if (rodIndex == 2) {
                // If Average is close to Best or Student, lift Average accordingly
                final bClose = bVisual > 0 && (aVisual - bVisual).abs() < 9;
                final sClose = sVisual > 0 && (aVisual - sVisual).abs() < 9;
                if (bClose && sVisual > 0 && (bVisual - sVisual).abs() < 9) {
                  displayText = '$valStr\n \n ';
                } else if (bClose || sClose) {
                  displayText = '$valStr\n ';
                }
              }

              return BarTooltipItem(
                displayText,
                TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  height: 1.1,
                ),
              );
            },
          ),
        ),
        barGroups: List.generate(points.length, (index) {
          final p = points[index];
          final sVisual = calcVisualHeight(p.studentValue);
          final bVisual = calcVisualHeight(p.bestValue);
          final aVisual = calcVisualHeight(p.averageValue);

          final showingIndicators = <int>[];
          if (p.studentValue != null && sVisual > 0) showingIndicators.add(0);
          if (p.bestValue != null && bVisual > 0) showingIndicators.add(1);
          if (p.averageValue != null && aVisual > 0) showingIndicators.add(2);

          return BarChartGroupData(
            x: index,
            barsSpace: 5,
            showingTooltipIndicators: showingIndicators,
            barRods: [
              BarChartRodData(
                toY: sVisual,
                color: studentColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              BarChartRodData(
                toY: bVisual,
                color: bestColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              BarChartRodData(
                toY: aVisual,
                color: avgColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(List<ScorecardChartPoint> points) {
    final maxY = _maxY;

    final studentSpots = <FlSpot>[];
    final bestSpots = <FlSpot>[];
    final avgSpots = <FlSpot>[];

    double calcVisualHeight(double? rawVal) {
      if (rawVal == null || rawVal <= 0) return 0.0;
      if (_metric == ScorecardMetric.rank) {
        return (maxY - rawVal + 1.0).clamp(1.0, maxY);
      }
      return rawVal.clamp(0.0, maxY);
    }

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.studentValue != null) {
        studentSpots.add(FlSpot(i.toDouble(), calcVisualHeight(p.studentValue)));
      }
      if (p.bestValue != null) {
        bestSpots.add(FlSpot(i.toDouble(), calcVisualHeight(p.bestValue)));
      }
      if (p.averageValue != null) {
        avgSpots.add(FlSpot(i.toDouble(), calcVisualHeight(p.averageValue)));
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(0, points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.05,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: max(1.0, maxY / 4),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.outlineLight,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final label = points[index].label;
                final truncated = label.length > 9 ? '${label.substring(0, 8)}…' : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    truncated,
                    style: AppTextStyles.labelXs.copyWith(
                      fontSize: 10,
                      color: AppColors.textMain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textMain,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                final label = index >= 0 && index < points.length ? points[index].label : '';
                String series = 'Value';
                if (barSpot.barIndex == 0) series = 'Student';
                if (barSpot.barIndex == 1) series = 'Best';
                if (barSpot.barIndex == 2) series = 'Avg';

                final point = index >= 0 && index < points.length ? points[index] : null;
                double? actualVal;
                if (barSpot.barIndex == 0) {
                  actualVal = point?.studentValue;
                } else if (barSpot.barIndex == 1) {
                  actualVal = point?.bestValue;
                } else {
                  actualVal = point?.averageValue;
                }
                final raw = actualVal ?? barSpot.y;

                String val;
                if (_metric == ScorecardMetric.percentage) {
                  val = '${raw.toStringAsFixed(2)}%';
                } else if (_metric == ScorecardMetric.rank) {
                  val = '#${raw.round()}';
                } else {
                  val = raw.toStringAsFixed(1);
                }

                return LineTooltipItem(
                  '$label\n$series: $val',
                  AppTextStyles.labelXs.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Student Line
          LineChartBarData(
            spots: studentSpots,
            isCurved: false,
            color: studentColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
          // Best Line
          LineChartBarData(
            spots: bestSpots,
            isCurved: false,
            color: bestColor,
            barWidth: 2,
            dashArray: [4, 4],
            dotData: const FlDotData(show: true),
          ),
          // Average Line
          LineChartBarData(
            spots: avgSpots,
            isCurved: false,
            color: avgColor,
            barWidth: 2,
            dashArray: [2, 2],
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Student', studentColor),
        const SizedBox(width: 16),
        _buildLegendItem('Class Best', bestColor),
        const SizedBox(width: 16),
        _buildLegendItem('Class Average', avgColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.labelXs.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
