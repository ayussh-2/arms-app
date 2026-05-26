import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/arms_top_app_bar.dart';
import '../widgets/arms_dashboard_button.dart';

/// Home dashboard matching dashboard.html.
/// Shows welcome text and feature cards for Attendance and Exams.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.onNavigateToAttendance,
    this.onNavigateToExams,
  });

  final VoidCallback? onNavigateToAttendance;
  final VoidCallback? onNavigateToExams;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ArmsTopAppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () {
              // Profile action – not yet implemented (YAGNI)
            },
            child: const CircleAvatar(
              backgroundColor: AppColors.cardSurface,
              child: Icon(Icons.person, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginPage,
          vertical: AppSpacing.stackMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome
            Text(
              'Welcome to\nPariksit ARMS',
              style: AppTextStyles.displayMobile,
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Feature cards
            ArmsDashboardButton(
              title: 'Attendance',
              description:
                  'Mark today\'s attendance, manage student leaves, or compile monthly report sheets.',
              icon: Icons.calendar_today,
              iconBgColor: AppColors.accent,
              onTap: () => onNavigateToAttendance?.call(),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            ArmsDashboardButton(
              title: 'Exams',
              description:
                  'Conduct examinations, feed grades, and generate marks sheets.',
              icon: Icons.assignment,
              iconBgColor: AppColors.accent,
              onTap: () => onNavigateToExams?.call(),
            ),
          ],
        ),
      ),
    );
  }
}
