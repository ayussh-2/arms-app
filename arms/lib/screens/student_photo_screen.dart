import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/auth/auth_service.dart';
import '../core/graphql/queries.dart';
import '../core/services/upload_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/arms_snackbar.dart';
import '../widgets/arms_top_app_bar.dart';
import 'student_photo/widgets/student_photo_capture_panel.dart';
import 'student_photo/widgets/student_photo_search_panel.dart';
import 'student_photo/student_camera_screen.dart';
import 'package:image_cropper/image_cropper.dart';

class StudentPhotoScreen extends StatefulWidget {
  const StudentPhotoScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<StudentPhotoScreen> createState() => _StudentPhotoScreenState();
}

class _StudentPhotoScreenState extends State<StudentPhotoScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSearching = false;
  Map<String, dynamic>? _selectedStudent;
  File? _pickedImage;
  bool _isUploading = false;
  List<Map<String, dynamic>> _searchResults = [];

  Future<void> _searchStudents(String query) async {
    final orgId = AuthService.currentAdmin?.organization?.id;
    if (orgId == null) {
      ArmsSnackbar.showError(context, 'Organization session not found. Please log in again.');
      return;
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getPaginatedStudents),
          variables: {
            'organisationId': orgId,
            'searchQuery': trimmedQuery,
            'page': 1,
            'limit': 20,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Search request timed out after 10s.'),
      );

      if (!mounted) return;

      if (result.hasException) {
        setState(() {
          _isSearching = false;
        });
        ArmsSnackbar.showError(context, 'Search failed: ${result.exception.toString()}');
        return;
      }

      final studentList = result.data?['getPaginatedStudents']?['students'] as List? ?? [];
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(
          studentList.map((s) => Map<String, dynamic>.from(s as Map)),
        );
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ArmsSnackbar.showError(context, 'Error searching student: $e');
      }
    }
  }

  void _onStudentSelected(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      _pickedImage = null;
    });
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final File? croppedFile = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentCameraScreen(),
          ),
        );
        if (croppedFile != null && mounted) {
          setState(() {
            _pickedImage = croppedFile;
          });
        }
      } else {
        final XFile? file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );

        if (file != null && mounted) {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: file.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Student Photo',
                toolbarColor: AppColors.primary,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                ],
              ),
              IOSUiSettings(
                title: 'Crop Student Photo',
                aspectRatioLockEnabled: true,
                resetAspectRatioEnabled: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                ],
              ),
            ],
          );
          if (croppedFile != null && mounted) {
            setState(() {
              _pickedImage = File(croppedFile.path);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Failed to process photo: $e');
      }
    }
  }

  Future<File> _processImageToJpeg(File sourceFile, {int? maxWidth, int? maxHeight, int quality = 85, required String suffix}) async {
    final bytes = await sourceFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image.');
    }

    img.Image resizedImage = image;
    if (maxWidth != null || maxHeight != null) {
      resizedImage = img.copyResize(
        image,
        width: maxWidth,
        height: maxHeight,
      );
    }

    final jpegBytes = img.encodeJpg(resizedImage, quality: quality);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(jpegBytes);
    return tempFile;
  }

  Future<void> _uploadAndAssignPhoto() async {
    if (_selectedStudent == null || _pickedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    File? mainJpegFile;
    File? thumbnailJpegFile;
    String? uploadedImageUrl;
    String? uploadedThumbnailUrl;

    try {
      final student = _selectedStudent!;
      final rollNo = (student['roll_no'] ?? 'unknown').toString().trim();
      final orgFolder = AuthService.currentAdmin?.organization?.name ?? 'org';
      final existingImageUrl = student['image_url'] as String?;

      // 1. Process/compress main image and generate thumbnail on the client
      mainJpegFile = await _processImageToJpeg(
        _pickedImage!,
        maxWidth: 800,
        maxHeight: 800,
        quality: 85,
        suffix: 'main',
      );

      thumbnailJpegFile = await _processImageToJpeg(
        _pickedImage!,
        maxWidth: 150,
        quality: 75,
        suffix: 'thumb',
      );

      // 2. Upload files to the Next.js API endpoint /api/student-images
      final uploadResult = await UploadService.uploadStudentImage(
        organisationFolder: orgFolder,
        rollNo: rollNo,
        imageFile: mainJpegFile,
        thumbnailFile: thumbnailJpegFile,
        existingImageUrl: existingImageUrl,
      );

      uploadedImageUrl = uploadResult['imageUrl'];
      uploadedThumbnailUrl = uploadResult['thumbnailUrl'];

      if (!mounted) return;

      // 3. Assign the uploaded image to the student using the Next.js REST endpoint
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        throw Exception('Organization session not found.');
      }

      await UploadService.assignStudentImage(
        rollNo: rollNo,
        imageUrl: uploadedImageUrl!,
        organisationId: orgId,
      );

      if (!mounted) return;

      setState(() {
        _selectedStudent = null;
        _pickedImage = null;
        _searchResults = [];
        _isUploading = false;
      });

      ArmsSnackbar.showSuccess(context, 'Student photo updated successfully!');
    } catch (e) {
      // 4. Prevent orphaned uploads by deleting uploaded files if the GraphQL mutation fails
      if (uploadedImageUrl != null && uploadedThumbnailUrl != null) {
        await UploadService.deleteStudentImage(
          imageUrl: uploadedImageUrl,
          thumbnailUrl: uploadedThumbnailUrl,
        );
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ArmsSnackbar.showError(context, 'Failed to upload photo: $e');
      }
    } finally {
      // 5. Clean up temporary local files
      try {
        if (mainJpegFile != null && await mainJpegFile.exists()) {
          await mainJpegFile.delete();
        }
        if (thumbnailJpegFile != null && await thumbnailJpegFile.exists()) {
          await thumbnailJpegFile.delete();
        }
      } catch (cleanupError) {
        print('Error cleaning up temp image files: $cleanupError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedStudent == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _selectedStudent = null;
          _pickedImage = null;
          _searchResults = [];
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: ArmsTopAppBar(
          title: "Upload Student Photo",
          leading: widget.showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                  onPressed: () {
                    Navigator.maybePop(context);
                  },
                )
              : null,
        ),
        body: _selectedStudent != null
            ? StudentPhotoCapturePanel(
                selectedStudent: _selectedStudent!,
                pickedImage: _pickedImage,
                isUploading: _isUploading,
                onBackPressed: () {
                  setState(() {
                    _selectedStudent = null;
                    _pickedImage = null;
                    _searchResults = [];
                  });
                },
                onCapturePhoto: _capturePhoto,
                onUploadAndAssignPhoto: _uploadAndAssignPhoto,
                onDiscardPickedImage: () {
                  setState(() {
                    _pickedImage = null;
                  });
                },
              )
            : StudentPhotoSearchPanel(
                onSearch: _searchStudents,
                isLoading: _isSearching,
                searchResults: _searchResults,
                onStudentSelected: _onStudentSelected,
              ),
      ),
    );
  }
}
