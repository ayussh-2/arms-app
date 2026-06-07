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
}
