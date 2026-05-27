import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../screens/shell_screen.dart';

/// Top app bar matching the dashboard.html design.
/// Flat white bar, no elevation, optional back button, title, and action icons.
class ArmsTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ArmsTopAppBar({
    super.key,
    this.title,
    this.showBackButton = false,
    this.actions,
    this.leading,
  });

  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.findAncestorStateOfType<ShellScreenState>()?.switchTab(0);
                }
              },
            )
          : leading,
      title: title != null
          ? Text(
              title!,
              style: AppTextStyles.headerSmall,
            )
          : null,
      centerTitle: false,
      actions: [
        ...?actions,
        const SizedBox(width: AppSpacing.stackSm),
      ],
    );
  }
}
