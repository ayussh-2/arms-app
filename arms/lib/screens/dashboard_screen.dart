import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/arms_top_app_bar.dart';
import '../core/auth/auth_service.dart';
import '../widgets/components/arms_avatar.dart';
import '../widgets/components/arms_confirm_dialog.dart';
import '../widgets/arms_snackbar.dart';
import '../core/utils/attendance_html_generator.dart';
import 'attendance/widgets/export_handlers.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.onNavigateToAttendance,
    this.onNavigateToExams,
    this.onNavigateToStudents,
  });

  final VoidCallback? onNavigateToAttendance;
  final VoidCallback? onNavigateToExams;
  final VoidCallback? onNavigateToStudents;

  void _openEvalBeeExport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('EvalBee CSV Export', style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Generate and export EvalBee OMR compatible CSV file for student roster (ROLLNO, NAME, CLASS, EMAILID, PHONENO).',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final admin = AuthService.currentAdmin;
                  final orgId = admin?.organization?.id;
                  if (orgId == null || orgId.isEmpty) {
                    ArmsSnackbar.showError(context, 'No organization associated with this account.');
                    return;
                  }
                  try {
                    await AttendanceExportHandler.exportEvalBeeCsv(
                      context: context,
                      orgId: orgId,
                      config: AttendanceExportConfig(
                        fromDate: DateTime.now(),
                        toDate: DateTime.now(),
                        reportType: 'Attendance Sheet',
                        session: AttendanceSession.morningIn,
                        mode: AttendanceSheetMode.sessionWise,
                        selectedSchoolId: orgId,
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ArmsSnackbar.showSuccess(context, 'EvalBee CSV exported successfully!');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ArmsSnackbar.showError(context, 'Export failed: $e');
                    }
                  }
                },
                icon: const Icon(Icons.download_outlined, color: Colors.white),
                label: const Text('Export EvalBee CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await ArmsConfirmDialog.show(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to sign out of ARMS?',
      confirmLabel: 'Logout',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true) {
      await AuthService.clearSession();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AuthService.currentAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ArmsTopAppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () {
              // Profile action
            },
            child: ArmsAvatar(
              imageUrl: admin?.imageURL,
              name: admin?.name ?? 'Admin',
              radius: 20,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
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
              'Welcome,\n${admin?.name ?? "Admin"}',
              style: AppTextStyles.displayMobile,
            ),
            if (admin?.organization?.displayName != null) ...[
              const SizedBox(height: 6),
              Text(
                admin!.organization!.displayName!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.stackLg),

            // Feature cards in a 2x2 Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: [
                ArmsGridDashboardButton(
                  title: 'Attendance',
                  icon: Icons.calendar_today,
                  iconColor: AppColors.accent,
                  onTap: () => onNavigateToAttendance?.call(),
                ),
                ArmsGridDashboardButton(
                  title: 'Exams',
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.accent,
                  onTap: () => onNavigateToExams?.call(),
                ),
                ArmsGridDashboardButton(
                  title: 'Students',
                  icon: Icons.people_outline_rounded,
                  iconColor: AppColors.accent,
                  onTap: () => onNavigateToStudents?.call(),
                ),
                ArmsGridDashboardButton(
                  title: 'EvalBee CSV',
                  icon: Icons.download_outlined,
                  iconColor: AppColors.accent,
                  onTap: () => _openEvalBeeExport(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ArmsGridDashboardButton extends StatelessWidget {
  const ArmsGridDashboardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              Text(
                title,
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
