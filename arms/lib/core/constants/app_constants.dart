class AppConstants {
  AppConstants._();

  static const String r2Host = 'https://pub-e9087294b3954d9b8d998b0d98e990ad.r2.dev';
  static const String schoolName = 'PARIKSIT';

  // Organization Branding URLs
  static const String orgLogoUrl = '$r2Host/$schoolName/branding/logo-1778301127097.jpg';
  static const String orgHeaderUrl = '$r2Host/$schoolName/branding/header-1778486029070.png';

  /// Returns the student thumbnail image URL for a given roll number.
  static String getStudentImageUrl(dynamic rollNo) {
    return '$r2Host/$schoolName/students/${rollNo}_thumb.jpg?v=2';
  }

  // API Configuration
  static const String defaultApiEndpoint = 'http://192.168.29.188:6582/api/graphql';
}
