import 'package:flutter/material.dart';
import '../core/debug/debug_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/arms_top_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final debugService = DebugService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        title: 'Settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginPage,
          vertical: AppSpacing.stackLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferences',
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: debugService.isDebugMode,
                builder: (context, isDebug, _) {
                  return SwitchListTile.adaptive(
                    value: isDebug,
                    onChanged: (val) {
                      debugService.isDebugMode.value = val;
                      if (!val) {
                        debugService.clearLogs();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val ? 'Debug network tracking enabled' : 'Debug network tracking disabled',
                          ),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    activeColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
                    title: Text(
                      'Enable Debug Mode',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Monitor GraphQL network requests, variables, responses, errors, and display the floating debug overlay.',
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Text(
              'Application Info',
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.info_outline,
                    title: 'Version',
                    value: '1.2.0-beta',
                  ),
                  const Divider(height: 1, color: AppColors.outlineLight),
                  _infoTile(
                    icon: Icons.domain_verification,
                    title: 'Environment',
                    value: 'Development',
                  ),
                  const Divider(height: 1, color: AppColors.outlineLight),
                  _infoTile(
                    icon: Icons.code,
                    title: 'Engine',
                    value: 'Flutter 3.x / GraphQL',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 16),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
