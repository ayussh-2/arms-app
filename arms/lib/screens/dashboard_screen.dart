import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/arms_top_app_bar.dart';
import '../core/auth/auth_service.dart';
import '../widgets/components/arms_avatar.dart';
import '../widgets/components/arms_confirm_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.onNavigateToAttendance,
    this.onNavigateToExams,
    this.onNavigateToPhotos,
  });

  final VoidCallback? onNavigateToAttendance;
  final VoidCallback? onNavigateToExams;
  final VoidCallback? onNavigateToPhotos;

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
                  title: 'Photos',
                  icon: Icons.photo_camera_front_outlined,
                  iconColor: AppColors.accent,
                  onTap: () => onNavigateToPhotos?.call(),
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
