import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../debug/debug_service.dart';

class UploadService {
  UploadService._();

  /// Reusable multipart file upload to Next.js R2 CDN API endpoints.
  /// 
  /// [apiUrlPath] is the endpoint path, e.g., '/api/leave-applications'.
  /// [organisationFolder] is the folder under which to store the file.
  /// [filenameBase] is the sanitized base name of the uploaded file.
  /// [file] is the selected file (either from ImagePicker or FilePicker).
  /// [formFieldName] is the form-data key name for the file, defaults to 'image'.
  /// [extraFields] allows passing additional arbitrary fields in form-data.
  static Future<String> uploadFile({
    required String apiUrlPath,
    required String organisationFolder,
    required String filenameBase,
    required File file,
    String formFieldName = 'image',
    Map<String, String>? extraFields,
  }) async {
    try {
      // 1. Derive base url dynamically from DebugService
      final rawUrl = DebugService().apiBaseUrl.value;
      final baseUri = Uri.parse(rawUrl);
      final hostUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      
      // Clean path and combine
      final cleanPath = apiUrlPath.startsWith('/') ? apiUrlPath : '/$apiUrlPath';
      final uploadUrl = Uri.parse('$hostUrl$cleanPath');

      // 2. Build multipart request
      final request = http.MultipartRequest('POST', uploadUrl);

      // Add standard required fields
      request.fields['organisationFolder'] = organisationFolder;
      request.fields['filenameBase'] = filenameBase;

      // Add extra custom fields if provided
      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      // 3. Infer file details
      final fileExtension = file.path.split('.').last.toLowerCase();

      // Add the file
      final multipartFile = await http.MultipartFile.fromPath(
        formFieldName,
        file.path,
        filename: '$filenameBase.$fileExtension',
      );
      request.files.add(multipartFile);

      // 4. Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload failed with status code ${response.statusCode}: ${response.body}');
      }

      // 5. Decode response
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      if (jsonData.containsKey('error')) {
        throw Exception(jsonData['error']);
      }

      // Standard CDN image/file URL key
      final fileUrl = jsonData['imageUrl'] ?? jsonData['fileUrl'] ?? jsonData['url'];
      if (fileUrl == null) {
        throw Exception('Response does not contain a file URL. Response body: ${response.body}');
      }

      return fileUrl as String;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload a student photo and its generated thumbnail to `/api/student-images`.
  /// Returns a Map containing 'imageUrl' and 'thumbnailUrl'.
  static Future<Map<String, String>> uploadStudentImage({
    required String organisationFolder,
    required String rollNo,
    required File imageFile,
    required File thumbnailFile,
    String? existingImageUrl,
  }) async {
    try {
      // 1. Derive base url dynamically from DebugService
      final rawUrl = DebugService().apiBaseUrl.value;
      final baseUri = Uri.parse(rawUrl);
      final hostUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      
      final uploadUrl = Uri.parse('$hostUrl/api/student-images');

      // 2. Build multipart request
      final request = http.MultipartRequest('POST', uploadUrl);

      // Add required text fields
      request.fields['rollNo'] = rollNo;
      request.fields['organisationFolder'] = organisationFolder;
      if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
        request.fields['existingImageUrl'] = existingImageUrl;
      }

      // Add the main image file as 'image' with Content-Type image/jpeg
      final imageMultipart = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: 'image.jpg',
      );
      request.files.add(imageMultipart);

      // Add the thumbnail file as 'thumbnail' with Content-Type image/jpeg
      final thumbnailMultipart = await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailFile.path,
        filename: 'thumbnail.jpg',
      );
      request.files.add(thumbnailMultipart);

      // 3. Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Upload request timed out after 20s.'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      // 4. Handle non-200 responses
      if (response.statusCode != 200) {
        throw Exception('Upload failed with status code ${response.statusCode}: ${response.body}');
      }

      // 5. Decode response
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      if (jsonData.containsKey('error')) {
        throw Exception(jsonData['error']);
      }

      final imageUrl = jsonData['imageUrl'];
      final thumbnailUrl = jsonData['thumbnailUrl'];

      if (imageUrl == null || thumbnailUrl == null) {
        throw Exception('Response does not contain imageUrl or thumbnailUrl. Response body: ${response.body}');
      }

      return {
        'imageUrl': imageUrl as String,
        'thumbnailUrl': thumbnailUrl as String,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Delete student image and thumbnail from the CDN to prevent orphaned files.
  static Future<void> deleteStudentImage({
    required String imageUrl,
    required String thumbnailUrl,
  }) async {
    try {
      final rawUrl = DebugService().apiBaseUrl.value;
      final baseUri = Uri.parse(rawUrl);
      final hostUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      
      final deleteUrl = Uri.parse('$hostUrl/api/student-images');

      final response = await http.delete(
        deleteUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageUrl': imageUrl,
          'thumbnailUrl': thumbnailUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Cleanup of orphaned uploads failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error cleaning up orphaned uploads: $e');
    }
  }

  /// Assign the uploaded image to the student using the Next.js REST endpoint `/api/student-images/assign`.
  static Future<void> assignStudentImage({
    required String rollNo,
    required String imageUrl,
    required String organisationId,
  }) async {
    try {
      final rawUrl = DebugService().apiBaseUrl.value;
      final baseUri = Uri.parse(rawUrl);
      final hostUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      
      final assignUrl = Uri.parse('$hostUrl/api/student-images/assign');

      final parsedRollNo = int.tryParse(rollNo) ?? 0;

      final response = await http.patch(
        assignUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rollNo': parsedRollNo,
          'imageUrl': imageUrl,
          'organisationId': organisationId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        String errMsg = 'Failed to assign image URL';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('error')) {
            errMsg = body['error'];
          }
        } catch (_) {}
        throw Exception('$errMsg (Status code: ${response.statusCode})');
      }

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      if (jsonData['success'] != true) {
        throw Exception(jsonData['error'] ?? 'Assignment was not successful.');
      }
    } catch (e) {
      rethrow;
    }
  }
}
