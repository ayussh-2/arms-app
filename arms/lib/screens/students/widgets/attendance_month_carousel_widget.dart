import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/scorecard_models.dart';

/// Month-by-month swipeable calendar attendance widget with colored status dots.
class AttendanceMonthCarouselWidget extends StatefulWidget {
  const AttendanceMonthCarouselWidget({
    super.key,
    required this.attendance,
  });

  final ScorecardAttendanceSummary attendance;

  @override
  State<AttendanceMonthCarouselWidget> createState() => _AttendanceMonthCarouselWidgetState();
}

class _AttendanceMonthCarouselWidgetState extends State<AttendanceMonthCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Default to the latest month with records if available
    final months = widget.attendance.calendar;
    final initialIndex = months.isNotEmpty ? months.length - 1 : 0;
    _currentPage = initialIndex;
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void didUpdateWidget(covariant AttendanceMonthCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attendance != widget.attendance) {
      final months = widget.attendance.calendar;
      final targetIndex = (months.isNotEmpty ? months.length - 1 : 0).clamp(0, months.isEmpty ? 0 : months.length - 1);
      if (_currentPage != targetIndex && mounted) {
        setState(() {
          _currentPage = targetIndex;
        });
        _pageController.jumpToPage(targetIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.attendance.calendar;

    if (months.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          'No attendance records found for this session.',
          style: AppTextStyles.labelXs,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attendance Overview Badges
        _buildSummaryHeader(),
        const SizedBox(height: 16),

        // Carousel Navigation Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.textMain),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _currentPage > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    months[_currentPage].monthName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFaint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${months[_currentPage].presentDays} / ${months[_currentPage].workingDays} Days '
                      '(${months[_currentPage].workingDays > 0 ? ((months[_currentPage].presentDays / months[_currentPage].workingDays) * 100).toStringAsFixed(1) : '0'}%)',
                      style: AppTextStyles.labelXs.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textMain),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _currentPage < months.length - 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Swipeable Month Grid
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: months.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildMonthGrid(months[index]);
            },
          ),
        ),

        const SizedBox(height: 12),

        // Attendance Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildKpiItem(
            'Present',
            '${widget.attendance.presentDays}',
            const Color(0xFF16A34A),
          ),
          _buildDivider(),
          _buildKpiItem(
            'Working',
            '${widget.attendance.workingDays}',
            AppColors.textMain,
          ),
          _buildDivider(),
          _buildKpiItem(
            'Percentage',
            '${widget.attendance.percentage.toStringAsFixed(1)}%',
            AppColors.primary,
          ),
          _buildDivider(),
          _buildKpiItem(
            'Leaves',
            '${widget.attendance.leaveDays}',
            const Color(0xFFD97706),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: AppColors.outlineLight,
    );
  }

  Widget _buildKpiItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
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

  Widget _buildMonthGrid(ScorecardMonthCalendar month) {
    const weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    // Determine leading empty cells
    int startingWeekday = 0;
    if (month.days.isNotEmpty) {
      try {
        final firstDate = DateTime.parse(month.days.first.date);
        startingWeekday = firstDate.weekday % 7; // Sunday is 0
      } catch (_) {
        startingWeekday = 0;
      }
    }

    final totalSlots = startingWeekday + month.days.length;

    return Column(
      children: [
        // Weekday initials
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((d) {
            final isWeekend = d == 'S';
            return SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  d,
                  style: AppTextStyles.labelXs.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isWeekend ? AppColors.errorText.withValues(alpha: 0.7) : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Day slots grid
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalSlots,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, index) {
              if (index < startingWeekday) {
                return const SizedBox.shrink();
              }
              final dayIndex = index - startingWeekday;
              final dayStatus = month.days[dayIndex];
              return _buildDayCell(dayStatus);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(ScorecardDayStatus day) {
    Color bg;
    Color text;

    switch (day.status.toLowerCase()) {
      case 'present':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        break;
      case 'absent':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      case 'leave':
        bg = const Color(0xFFFEF08A);
        text = const Color(0xFF854D0E);
        break;
      case 'holiday':
      case 'h':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        break;
      case 'unmarked':
      default:
        bg = AppColors.surfaceVariant.withValues(alpha: 0.3);
        text = AppColors.textSecondary;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: AppTextStyles.labelXs.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendDot('Present', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
        const SizedBox(width: 14),
        _buildLegendDot('Absent', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
        const SizedBox(width: 14),
        _buildLegendDot('Leave', const Color(0xFF854D0E), const Color(0xFFFEF08A)),
        const SizedBox(width: 14),
        _buildLegendDot('Holiday', const Color(0xFF1E40AF), const Color(0xFFDBEAFE)),
      ],
    );
  }

  Widget _buildLegendDot(String label, Color dotColor, Color dotBg) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotBg,
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
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
