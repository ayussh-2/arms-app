import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/arms_top_app_bar.dart';
import '../widgets/arms_dashboard_button.dart';
import '../core/auth/auth_service.dart';
import '../core/utils/image_url_helper.dart';

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
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Confirm Logout',
            style: AppTextStyles.headerSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to sign out of ARMS?',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                elevation: 0,
              ),
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.clearSession();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
            ),
          ],
        );
      },
    );
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
            child: CircleAvatar(
              backgroundColor: AppColors.cardSurface,
              backgroundImage: admin?.imageURL != null && admin!.imageURL!.isNotEmpty
                  ? NetworkImage(ImageUrlHelper.sanitizeUrl(admin.imageURL)!)
                  : null,
              child: admin?.imageURL == null || admin!.imageURL!.isEmpty
                  ? const Icon(Icons.person, color: AppColors.textSecondary)
                  : null,
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
