class AppStringUtils {
  /// Extracts initials from a full name (e.g., 'John Doe' -> 'JD')
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  /// Sanitizes a string for use as a filename
  static String sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
  }
}
