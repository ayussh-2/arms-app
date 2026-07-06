import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCompressUtils {
  /// Compresses [imageFile] to ensure it's under [maxSizeBytes] as a JPG,
  /// and saves it in the temporary directory.
  /// Returns the path to the compressed [File].
  static Future<File> compressImageUnderSize(File imageFile, {int maxSizeBytes = 500 * 1024}) async {
    final bytes = await imageFile.readAsBytes();
    
    if (bytes.length <= maxSizeBytes) {
      // Already under the limit! Just return the original file
      return imageFile;
    }

    // Attempt decoding
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode selected image.');
    }

    img.Image resizedImage = decodedImage;
    // Downscale if image dimensions are extremely large to speed up compression
    if (decodedImage.width > 1600 || decodedImage.height > 1600) {
      final double aspectRatio = decodedImage.width / decodedImage.height;
      int newWidth, newHeight;
      if (decodedImage.width > decodedImage.height) {
        newWidth = 1600;
        newHeight = (1600 / aspectRatio).round();
      } else {
        newHeight = 1600;
        newWidth = (1600 * aspectRatio).round();
      }
      resizedImage = img.copyResize(decodedImage, width: newWidth, height: newHeight);
    }

    int quality = 85;
    bool sizeOk = false;
    Uint8List jpegBytes = Uint8List(0);

    // Iterative compression by reducing JPEG quality
    while (!sizeOk && quality >= 15) {
      jpegBytes = img.encodeJpg(resizedImage, quality: quality);
      if (jpegBytes.length <= maxSizeBytes) {
        sizeOk = true;
        break;
      }
      quality -= 10;
    }

    // If it is still too large, downscale dimensions progressively
    if (!sizeOk) {
      double scale = 0.8;
      while (!sizeOk && scale >= 0.2) {
        final scaled = img.copyResize(
          resizedImage,
          width: (resizedImage.width * scale).round(),
          height: (resizedImage.height * scale).round(),
        );
        jpegBytes = img.encodeJpg(scaled, quality: 30);
        if (jpegBytes.length <= maxSizeBytes) {
          sizeOk = true;
          break;
        }
        scale -= 0.2;
      }
    }

    // Fallback: If still too large, force encode with minimum quality and low resolution
    if (!sizeOk) {
      final forcedResized = img.copyResize(resizedImage, width: 800);
      jpegBytes = img.encodeJpg(forcedResized, quality: 15);
    }

    // Save to temp directory
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/attachment_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(jpegBytes);
    return tempFile;
  }
}
