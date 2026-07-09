import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/image_url_helper.dart';

/// A standardized CircleAvatar widget for displaying student or user profile photos.
/// Handles image URL validation, sanitization, loading fallbacks, and rendering initials.
class ArmsAvatar extends StatelessWidget {
  const ArmsAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 20.0,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? imageUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final sanitizedUrl = imageUrl != null && imageUrl!.trim().isNotEmpty
        ? ImageUrlHelper.sanitizeUrl(imageUrl!.trim())
        : null;

    final bg = backgroundColor ?? AppColors.primary.withValues(alpha: 0.1);
    final fg = foregroundColor ?? AppColors.primary;

    if (sanitizedUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: NetworkImage(sanitizedUrl),
      );
    }

    final initialText = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initialText,
        style: AppTextStyles.bodyMedium.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7, // scales text size to fit avatar size
        ),
      ),
    );
  }
}
