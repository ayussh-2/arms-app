import '../constants/app_constants.dart';

class ImageUrlHelper {
  ImageUrlHelper._();

  /// Prepend the R2 host CDN prefix to an image path if it is not already an absolute URL.
  static String? sanitizeUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    
    // Clean redundant starting slashes
    final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '${AppConstants.r2Host}/$cleanPath';
  }
}
