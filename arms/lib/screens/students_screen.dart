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
import '../widgets/arms_picker_sheet.dart';
import 'students/widgets/student_capture_panel.dart';
import 'students/widgets/student_search_panel.dart';
import 'students/student_camera_screen.dart';
import 'package:image_cropper/image_cropper.dart';
import '../core/utils/image_url_helper.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<StudentsScreen> createState() => StudentsScreenState();
}

class StudentsScreenState extends State<StudentsScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSearching = false;
  Map<String, dynamic>? _selectedStudent;
  File? _pickedImage;
  bool _isUploading = false;
  List<Map<String, dynamic>> _searchResults = [];

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _currentQuery = '';

  List<dynamic> _schools = [];
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];
  bool _hasLookupsFetched = false;

  String? _selectedSchoolId;
  String? _selectedSchoolName;
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSectionId;
  String? _selectedSectionName;
  bool? _havingPhoto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents(isRefresh: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLookupsFetched) {
      _hasLookupsFetched = true;
      _fetchLookups();
    }
  }

  Future<void> _fetchLookups() async {
    final admin = AuthService.currentAdmin;
    final orgId = admin?.organization?.id;
    if (orgId == null || orgId.isEmpty) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'No organization associated with this account.');
      }
      return;
    }

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getLookups),
          variables: {'organisationId': orgId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('getLookups query timed out.'),
      );

      if (!mounted) return;

      if (result.hasException) {
        final errorMsg = 'Failed to load lookups: ${result.exception.toString()}';
        debugPrint(errorMsg);
        ArmsSnackbar.showError(context, errorMsg);
        return;
      }

      final lookups = result.data?['getLookups'];
      if (lookups == null) {
        const errorMsg = 'No lookup data returned.';
        ArmsSnackbar.showError(context, errorMsg);
        return;
      }

      setState(() {
        _schools = List.from(lookups['schools'] ?? []);
        _classes = List.from(lookups['classes'] ?? []);
        _sections = List.from(lookups['sections'] ?? []);
      });
    } catch (e) {
      if (mounted) {
        final errorMsg = 'Error fetching lookups: $e';
        debugPrint(errorMsg);
        ArmsSnackbar.showError(context, errorMsg);
      }
    }
  }

  void _showLookupPicker({
    required String title,
    required List<dynamic> items,
    required String errorMsg,
    required void Function(dynamic) onSelected,
  }) {
    if (items.isEmpty) {
      ArmsSnackbar.showError(context, errorMsg);
      return;
    }
    ArmsPickerSheet.show<dynamic>(
      context: context,
      title: title,
      items: items,
      itemLabel: (item) => item['name']?.toString() ?? '',
      onItemSelected: onSelected,
    );
  }

  void _onShowSchoolPicker() {
    _showLookupPicker(
      title: 'Select School',
      items: _schools,
      errorMsg: 'No schools found.',
      onSelected: (item) {
        setState(() {
          _selectedSchoolId = item['id'];
          _selectedSchoolName = item['name'];
        });
        _loadStudents(isRefresh: true);
      },
    );
  }

  void _onShowClassPicker() {
    _showLookupPicker(
      title: 'Select Class',
      items: _classes,
      errorMsg: 'No classes found.',
      onSelected: (item) {
        setState(() {
          _selectedClassId = item['id'];
          _selectedClassName = item['name'];
        });
        _loadStudents(isRefresh: true);
      },
    );
  }

  void _onShowSectionPicker() {
    _showLookupPicker(
      title: 'Select Section',
      items: _sections,
      errorMsg: 'No sections found.',
      onSelected: (item) {
        setState(() {
          _selectedSectionId = item['id'];
          _selectedSectionName = item['name'];
        });
        _loadStudents(isRefresh: true);
      },
    );
  }

  void _onHavingPhotoChanged(bool? value) {
    setState(() {
      _havingPhoto = value;
    });
    _loadStudents(isRefresh: true);
  }

  void _clearSchool() {
    setState(() {
      _selectedSchoolId = null;
      _selectedSchoolName = null;
    });
    _loadStudents(isRefresh: true);
  }

  void _clearClass() {
    setState(() {
      _selectedClassId = null;
      _selectedClassName = null;
    });
    _loadStudents(isRefresh: true);
  }

  void _clearSection() {
    setState(() {
      _selectedSectionId = null;
      _selectedSectionName = null;
    });
    _loadStudents(isRefresh: true);
  }

  void _clearHavingPhoto() {
    setState(() {
      _havingPhoto = null;
    });
    _loadStudents(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedSchoolId = null;
      _selectedSchoolName = null;
      _selectedClassId = null;
      _selectedClassName = null;
      _selectedSectionId = null;
      _selectedSectionName = null;
      _havingPhoto = null;
    });
    _loadStudents(isRefresh: true);
  }

  Future<void> _loadStudents({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _searchResults = [];
        _isSearching = true;
      });
    } else {
      if (!_hasMore || _isLoadingMore || _isSearching) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    final orgId = AuthService.currentAdmin?.organization?.id;
    if (orgId == null) {
      if (mounted) {
        ArmsSnackbar.showError(context, 'Organization session not found. Please log in again.');
      }
      return;
    }

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getPaginatedStudents),
          variables: {
            'organisationId': orgId,
            'searchQuery': _currentQuery.trim(),
            'page': _currentPage,
            'limit': 10,
            'classId': _selectedClassId,
            'schoolId': _selectedSchoolId,
            'sectionId': _selectedSectionId,
            'havingPhoto': _havingPhoto,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timed out after 10s.'),
      );

      if (!mounted) return;

      if (result.hasException) {
        setState(() {
          _isSearching = false;
          _isLoadingMore = false;
        });
        ArmsSnackbar.showError(context, 'Failed to load students: ${result.exception.toString()}');
        return;
      }

      final studentList = result.data?['getPaginatedStudents']?['students'] as List? ?? [];
      final newStudents = List<Map<String, dynamic>>.from(
        studentList.map((s) => Map<String, dynamic>.from(s as Map)),
      );

      setState(() {
        if (isRefresh) {
          _searchResults = newStudents;
          _isSearching = false;
        } else {
          _searchResults.addAll(newStudents);
          _isLoadingMore = false;
        }
        
        if (newStudents.length < 10) {
          _hasMore = false;
        } else {
          _currentPage++;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _isLoadingMore = false;
        });
        ArmsSnackbar.showError(context, 'Error loading students: $e');
      }
    }
  }

  Future<void> _searchStudents(String query) async {
    _currentQuery = query;
    await _loadStudents(isRefresh: true);
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
        // Update the student's image URL locally in the list in-place
        final rNo = student['roll_no'];
        for (var s in _searchResults) {
          if (s['roll_no'] == rNo) {
            s['image_url'] = uploadedImageUrl;
            break;
          }
        }
        _selectedStudent = null;
        _pickedImage = null;
        _isUploading = false;
      });

      // Clear the network image cache for the updated URLs so Flutter fetches the new files
      final fullUrl = ImageUrlHelper.sanitizeUrl(uploadedImageUrl);
      if (fullUrl != null) {
        NetworkImage(fullUrl).evict();
      }
      if (uploadedThumbnailUrl != null) {
        final thumbUrl = ImageUrlHelper.sanitizeUrl(uploadedThumbnailUrl);
        if (thumbUrl != null) {
          NetworkImage(thumbUrl).evict();
        }
      }

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
        debugPrint('Error cleaning up temp image files: $cleanupError');
      }
    }
  }



  bool handleBack() {
    if (_selectedStudent != null) {
      setState(() {
        _selectedStudent = null;
        _pickedImage = null;
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      appBar: ArmsTopAppBar(
        title: _selectedStudent != null
            ? (_selectedStudent!['name']?.toString() ?? 'Student Details')
            : "Students",
        leading: (widget.showBackButton || _selectedStudent != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                onPressed: () {
                  if (_selectedStudent != null) {
                    setState(() {
                      _selectedStudent = null;
                      _pickedImage = null;
                    });
                  } else {
                    Navigator.maybePop(context);
                  }
                },
              )
            : null,
      ),
      body: _selectedStudent != null
          ? StudentCapturePanel(
              selectedStudent: _selectedStudent!,
              pickedImage: _pickedImage,
              isUploading: _isUploading,
              onBackPressed: () {
                setState(() {
                  _selectedStudent = null;
                  _pickedImage = null;
                });
              },
              onCapturePhoto: _capturePhoto,
              onUploadAndAssignPhoto: _uploadAndAssignPhoto,
              onDiscardPickedImage: () {
                setState(() {
                  _pickedImage = null;
                });
              },
              schools: _schools,
              classes: _classes,
              sections: _sections,
              onDetailsUpdated: (updatedStudent) {
                setState(() {
                  _selectedStudent = updatedStudent;
                });
                _loadStudents(isRefresh: true);
              },
            )
          : StudentSearchPanel(
              onSearch: _searchStudents,
              isLoading: _isSearching,
              searchResults: _searchResults,
              onStudentSelected: _onStudentSelected,
              onLoadMore: () => _loadStudents(isRefresh: false),
              isLoadingMore: _isLoadingMore,
              hasMore: _hasMore,
              initialQuery: _currentQuery,
              schools: _schools,
              classes: _classes,
              sections: _sections,
              selectedSchoolName: _selectedSchoolName,
              selectedClassName: _selectedClassName,
              selectedSectionName: _selectedSectionName,
              havingPhoto: _havingPhoto,
              onShowSchoolPicker: _onShowSchoolPicker,
              onShowClassPicker: _onShowClassPicker,
              onShowSectionPicker: _onShowSectionPicker,
              onHavingPhotoChanged: _onHavingPhotoChanged,
              onClearFilters: _clearFilters,
              onClearSchool: _clearSchool,
              onClearClass: _clearClass,
              onClearSection: _clearSection,
              onClearHavingPhoto: _clearHavingPhoto,
            ),
    );

    if (widget.showBackButton) {
      return PopScope(
        canPop: _selectedStudent == null,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() {
            _selectedStudent = null;
            _pickedImage = null;
          });
        },
        child: scaffold,
      );
    }

    return scaffold;
  }
}
