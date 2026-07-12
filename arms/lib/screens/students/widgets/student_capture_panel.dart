import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/graphql/queries.dart';
import '../../../core/auth/auth_service.dart';
import '../../../widgets/arms_snackbar.dart';
import '../../../widgets/components/arms_date_field.dart';

class StudentCapturePanel extends StatefulWidget {
  const StudentCapturePanel({
    super.key,
    required this.selectedStudent,
    required this.pickedImage,
    required this.isUploading,
    required this.onBackPressed,
    required this.onCapturePhoto,
    required this.onUploadAndAssignPhoto,
    required this.onDiscardPickedImage,
    required this.schools,
    required this.classes,
    required this.sections,
    this.onDetailsUpdated,
  });

  final Map<String, dynamic> selectedStudent;
  final File? pickedImage;
  final bool isUploading;

  final VoidCallback onBackPressed;
  final ValueChanged<ImageSource> onCapturePhoto;
  final VoidCallback onUploadAndAssignPhoto;
  final VoidCallback onDiscardPickedImage;
  final List<dynamic> schools;
  final List<dynamic> classes;
  final List<dynamic> sections;
  final ValueChanged<Map<String, dynamic>>? onDetailsUpdated;

  @override
  State<StudentCapturePanel> createState() => _StudentCapturePanelState();
}

class _StudentCapturePanelState extends State<StudentCapturePanel> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isEditable = false;

  List<dynamic> _assignedTags = [];
  List<dynamic> _availableTags = [];
  bool _isTagEditing = false;
  String? _selectedTagCategory;
  String? _selectedTagIdToAdd;


  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _alumni = [];
  String? _rawDob;

  final _nameController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedSchoolId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedFlBatchId;
  String? _selectedCategory;
  String? _selectedGender;

  final List<String> _categories = ['st', 'sc', 'obc', 'ews', 'pwd'];
  final List<String> _genders = ['male', 'female'];

  String? _nameError;
  String? _rollNoError;
  String? _emailError;
  String? _phone1Error;
  String? _phone2Error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(covariant StudentCapturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStudent['id'] != oldWidget.selectedStudent['id']) {
      _loadData();
    } else if (widget.selectedStudent != oldWidget.selectedStudent && !_isEditable) {
      if (_studentData != null) {
        setState(() {
          _studentData!['name'] = widget.selectedStudent['name'];
          _studentData!['roll_no'] = widget.selectedStudent['roll_no'];
          _syncFieldsFromStudentData();
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        throw Exception("Organization session not found.");
      }

      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getStudentDetails),
          variables: {
            'id': widget.selectedStudent['id'],
            'organisationId': orgId,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      final alumniResult = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getAlumni),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      final tagsResult = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getAvailableTags),
          variables: {'organisationId': orgId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }
      if (alumniResult.hasException) {
        throw Exception(alumniResult.exception.toString());
      }
      if (tagsResult.hasException) {
        throw Exception(tagsResult.exception.toString());
      }

      final student = result.data?['getStudentDetails'];
      final alumniList = alumniResult.data?['getAlumni'] as List? ?? [];
      final availableTagsList = tagsResult.data?['getAvailableTags'] as List? ?? [];

      if (student != null) {
        if (mounted) {
          setState(() {
            _studentData = Map<String, dynamic>.from(student);
            _alumni = List<Map<String, dynamic>>.from(
              alumniList.map((a) => Map<String, dynamic>.from(a as Map)),
            );
            _availableTags = List<dynamic>.from(availableTagsList);
            _syncFieldsFromStudentData();
            _isLoading = false;
          });
        }
      } else {
        throw Exception("No student details returned.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        ArmsSnackbar.showError(context, 'Error loading student details: $e');
      }
    }
  }

  void _syncFieldsFromStudentData() {
    if (_studentData == null) return;
    final student = _studentData!;
    _nameController.text = student['name'] ?? '';
    _rollNoController.text = (student['roll_no'] ?? '').toString();
    _fatherNameController.text = student['father_name'] ?? '';
    _motherNameController.text = student['mother_name'] ?? '';
    _rawDob = student['dob'] ?? '';
    _dobController.text = _formatDobForDisplay(_rawDob);
    _emailController.text = student['email'] ?? '';
    _phone1Controller.text = student['phone1'] ?? '';
    _phone2Controller.text = student['phone2'] ?? '';
    _passwordController.text = student['password'] ?? '';
    _addressController.text = student['address'] ?? '';

    _selectedSchoolId = student['school_id'];
    _selectedClassId = student['class_id'];
    _selectedSectionId = student['section_id'];
    _selectedFlBatchId = student['fl_batch_id'];

    _assignedTags = List<dynamic>.from(student['tags'] ?? []);

    final rawCategory = student['category']?.toString().toLowerCase();
    if (rawCategory != null && _categories.contains(rawCategory)) {
      _selectedCategory = rawCategory;
    } else {
      _selectedCategory = null;
    }

    final rawGender = student['gender']?.toString().toLowerCase().trim();
    if (rawGender != null) {
      if (rawGender == 'm' || rawGender == 'male') {
        _selectedGender = 'male';
      } else if (rawGender == 'f' || rawGender == 'female') {
        _selectedGender = 'female';
      } else {
        _selectedGender = null;
      }
    } else {
      _selectedGender = null;
    }
  }


  void _resetForm() {
    _syncFieldsFromStudentData();
    setState(() {
      _nameError = null;
      _rollNoError = null;
      _emailError = null;
      _phone1Error = null;
      _phone2Error = null;
    });
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String _formatDobForDisplay(String? rawDob) {
    if (rawDob == null || rawDob.isEmpty) return '';
    try {
      final parts = rawDob.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null && month >= 1 && month <= 12) {
          final yearStr = year.toString();
          final shortYear = yearStr.length >= 2 ? yearStr.substring(yearStr.length - 2) : yearStr;
          return "${day.toString().padLeft(2, '0')} ${_monthNames[month - 1]} $shortYear";
        }
      }
      final dt = DateTime.tryParse(rawDob);
      if (dt != null) {
        final yearStr = dt.year.toString();
        final shortYear = yearStr.length >= 2 ? yearStr.substring(yearStr.length - 2) : yearStr;
        return "${dt.day.toString().padLeft(2, '0')} ${_monthNames[dt.month - 1]} $shortYear";
      }
    } catch (_) {}
    return rawDob;
  }

  int? _calculateAge(String? rawDob) {
    if (rawDob == null || rawDob.trim().isEmpty) return null;
    try {
      final dob = DateTime.tryParse(rawDob.trim());
      if (dob == null) return null;
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age >= 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? initialDate;
    if (_rawDob != null && _rawDob!.isNotEmpty) {
      initialDate = DateTime.tryParse(_rawDob!);
    }
    initialDate ??= DateTime(2010);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _rawDob = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _dobController.text = _formatDobForDisplay(_rawDob);
      });
    }
  }

  Future<void> _saveDetails() async {
    setState(() {
      _nameError = null;
      _rollNoError = null;
      _emailError = null;
      _phone1Error = null;
      _phone2Error = null;
    });

    bool hasError = false;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Student Name is required.');
      hasError = true;
    }

    final rollNoStr = _rollNoController.text.trim();
    final rollNoVal = int.tryParse(rollNoStr);
    if (rollNoStr.isEmpty) {
      setState(() => _rollNoError = 'Admission No. / Roll No. is required.');
      hasError = true;
    } else if (rollNoVal == null) {
      setState(() => _rollNoError = 'Admission No. / Roll No. must be a valid integer.');
      hasError = true;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegExp.hasMatch(email)) {
        setState(() => _emailError = 'Please enter a valid Email address.');
        hasError = true;
      }
    }

    final phone1 = _phone1Controller.text.trim();
    if (phone1.isNotEmpty) {
      final phoneRegExp = RegExp(r'^[0-9]{10}$');
      if (!phoneRegExp.hasMatch(phone1)) {
        setState(() => _phone1Error = 'Please enter a valid 10-digit Phone 1 number.');
        hasError = true;
      }
    }

    final phone2 = _phone2Controller.text.trim();
    if (phone2.isNotEmpty) {
      final phoneRegExp = RegExp(r'^[0-9]{10}$');
      if (!phoneRegExp.hasMatch(phone2)) {
        setState(() => _phone2Error = 'Please enter a valid 10-digit Phone 2 number.');
        hasError = true;
      }
    }

    if (hasError) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final orgId = AuthService.currentAdmin?.organization?.id;
      if (orgId == null) {
        throw Exception("Organization session not found.");
      }

      final input = {
        'name': name,
        'father_name': _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
        'mother_name': _motherNameController.text.trim().isEmpty ? null : _motherNameController.text.trim(),
        'dob': _rawDob != null && _rawDob!.trim().isNotEmpty ? _rawDob!.trim() : null,
        'school_id': _selectedSchoolId,
        'class_id': _selectedClassId,
        'section_id': _selectedSectionId,
        'roll_no': rollNoVal,
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'password': _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        'phone1': _phone1Controller.text.trim().isEmpty ? null : _phone1Controller.text.trim(),
        'phone2': _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
        'category': _selectedCategory,
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'gender': _selectedGender,
        'age': _calculateAge(_rawDob),
        'fl_batch_id': _selectedFlBatchId,
        'image_url': _studentData?['image_url'],
        'image_version': _studentData?['image_version'],
      };

      final result = await client.mutate(
        MutationOptions(
          document: gql(GqlQueries.updateStudentDetails),
          variables: {
            'id': widget.selectedStudent['id'],
            'organisationId': orgId,
            'input': input,
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      if (mounted) {
        ArmsSnackbar.showSuccess(context, 'Student details updated successfully!');

        final selectedClass = widget.classes.firstWhere(
          (c) => c['id']?.toString() == _selectedClassId,
          orElse: () => null,
        );
        final selectedSection = widget.sections.firstWhere(
          (s) => s['id']?.toString() == _selectedSectionId,
          orElse: () => null,
        );

        final updatedStudentMap = {
          'id': widget.selectedStudent['id'],
          'name': name,
          'roll_no': rollNoVal,
          'image_url': _studentData?['image_url'] ?? widget.selectedStudent['image_url'],
          'class': selectedClass != null ? {'id': selectedClass['id'], 'name': selectedClass['name']} : null,
          'section': selectedSection != null ? {'id': selectedSection['id'], 'name': selectedSection['name']} : null,
        };

        setState(() {
          _studentData!['name'] = name;
          _studentData!['roll_no'] = rollNoVal;
          _studentData!['father_name'] = _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim();
          _studentData!['mother_name'] = _motherNameController.text.trim().isEmpty ? null : _motherNameController.text.trim();
          _studentData!['dob'] = _rawDob != null && _rawDob!.trim().isNotEmpty ? _rawDob!.trim() : null;
          _studentData!['school_id'] = _selectedSchoolId;
          _studentData!['class_id'] = _selectedClassId;
          _studentData!['section_id'] = _selectedSectionId;
          _studentData!['email'] = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
          _studentData!['password'] = _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim();
          _studentData!['phone1'] = _phone1Controller.text.trim().isEmpty ? null : _phone1Controller.text.trim();
          _studentData!['phone2'] = _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim();
          _studentData!['category'] = _selectedCategory;
          _studentData!['address'] = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
          _studentData!['gender'] = _selectedGender;
          _studentData!['fl_batch_id'] = _selectedFlBatchId;

          _syncFieldsFromStudentData();
          _isSaving = false;
          _isEditable = false;
        });

        if (widget.onDetailsUpdated != null) {
          widget.onDetailsUpdated!(updatedStudentMap);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ArmsSnackbar.showError(context, 'Failed to update student details: $e');
      }
    }
  }

  InputDecoration _getInputDecoration({String? hintText, String? errorText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
      errorText: errorText,
      errorStyle: const TextStyle(height: 0.8),
      filled: true,
      fillColor: _isEditable ? AppColors.cardSurface : AppColors.surfaceVariant.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.15), width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.05), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorText, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorText, width: 2),
      ),
    );
  }

  Widget _buildFieldWrapper(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, {String? placeholder, TextInputType? keyboardType, String? errorText}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: _isEditable,
      style: AppTextStyles.bodyMedium.copyWith(
        color: _isEditable ? AppColors.textMain : AppColors.textSecondary,
      ),
      decoration: _getInputDecoration(hintText: placeholder, errorText: errorText),
    );
  }

  Widget _buildDobField() {
    return ArmsDateField(
      controller: _dobController,
      hintText: 'dd mm yyyy',
      onTap: _isEditable ? () => _selectDate(context) : () {},
      fillColor: _isEditable ? AppColors.cardSurface : AppColors.cardSurface.withValues(alpha: 0.5),
      hasBorder: true,
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? hintText,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        padding: EdgeInsets.zero,
        style: AppTextStyles.bodyMedium.copyWith(
          color: onChanged != null ? AppColors.textMain : AppColors.textSecondary,
        ),
        decoration: _getInputDecoration(hintText: hintText),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: onChanged != null ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.3),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.labelXsUppercase.copyWith(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showTagDetails(Map<String, dynamic> tag) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(tag['name'] ?? 'Tag Details', style: const TextStyle(color: AppColors.textMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category: ${tag['type'] ?? 'None'}', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(tag['assignedByLabel'] ?? 'Assignment info unavailable', style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRemoveTag(Map<String, dynamic> tag) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              title: const Text('Remove Tag', style: TextStyle(color: AppColors.textMain)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type "remove" to confirm removing the tag "${tag['name']}".', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    style: const TextStyle(color: AppColors.textMain),
                    decoration: const InputDecoration(
                      hintText: 'Type remove',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.outline)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                    ),
                    onChanged: (_) {
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.primary)),
                ),
                TextButton(
                  onPressed: confirmController.text.trim().toLowerCase() == 'remove'
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.errorText,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (confirm == true) {
      setState(() {
        _isSaving = true;
      });
      try {
        final client = GraphQLProvider.of(context).value;
        final result = await client.mutate(
          MutationOptions(
            document: gql(GqlQueries.removeStudentTag),
            variables: {
              'studentId': widget.selectedStudent['id'],
              'tagId': tag['id'],
            },
          ),
        );

        if (!mounted) return;

        if (result.hasException) {
          throw Exception(result.exception.toString());
        }

        ArmsSnackbar.showSuccess(context, 'Tag removed successfully!');
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        ArmsSnackbar.showError(context, 'Failed to remove tag: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  Future<void> _assignTag() async {
    if (_selectedTagIdToAdd == null || _selectedTagIdToAdd!.isEmpty) return;

    final adminId = AuthService.currentAdmin?.id;
    if (adminId == null) {
      ArmsSnackbar.showError(context, 'Admin session not found.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(
        MutationOptions(
          document: gql(GqlQueries.assignStudentTag),
          variables: {
            'studentId': widget.selectedStudent['id'],
            'tagId': _selectedTagIdToAdd,
            'assignedBy': adminId,
            'assignedByType': 'admin',
          },
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      ArmsSnackbar.showSuccess(context, 'Tag added successfully!');
      setState(() {
        _selectedTagIdToAdd = null;
      });
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ArmsSnackbar.showError(context, 'Failed to add tag: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildTagPickerSection() {
    final categories = _availableTags
        .map((tag) => tag['type']?.toString().trim() ?? '')
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();
    categories.sort((a, b) => a.compareTo(b));

    final tagsInSelectedCategory = _availableTags
        .where((tag) => (tag['type']?.toString().trim() ?? '') == _selectedTagCategory && 
                        !_assignedTags.any((assigned) => assigned['id'] == tag['id']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                value: _selectedTagCategory,
                hintText: 'Select category',
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select Category')),
                  ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedTagCategory = val;
                    _selectedTagIdToAdd = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdownField<String>(
                value: _selectedTagIdToAdd,
                hintText: 'Select tag name',
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select Tag')),
                  ...tagsInSelectedCategory.map((t) => DropdownMenuItem(
                        value: t['id']?.toString(),
                        child: Text(t['name']?.toString() ?? ''),
                      )),
                ],
                onChanged: _selectedTagCategory == null
                    ? null
                    : (val) {
                        setState(() {
                          _selectedTagIdToAdd = val;
                        });
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _selectedTagIdToAdd == null || _isSaving ? null : _assignTag,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Tag'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    // final name = widget.selectedStudent['name'] ?? 'No Name';
    // final rollNo = widget.selectedStudent['roll_no'] ?? 'No Roll No';
    final currentImgUrl = widget.selectedStudent['image_url'] as String?;
    final hasCurrentImg = currentImgUrl != null && currentImgUrl.isNotEmpty;

    // final className = widget.selectedStudent['class']?['name']?.toString() ?? 'Unknown Class';
    // final sectionName = widget.selectedStudent['section']?['name']?.toString() ?? 'Unknown Section';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginPage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Details Card
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         AppColors.primary.withValues(alpha: 0.05),
          //         AppColors.primary.withValues(alpha: 0.01),
          //       ],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     borderRadius: BorderRadius.circular(16),
          //     border: Border.all(
          //       color: AppColors.primary.withValues(alpha: 0.1),
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Text(
          //               name,
          //               style: AppTextStyles.headerSmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
          //             ),
          //             const SizedBox(height: 6),
          //             Row(
          //               children: [
          //                 Container(
          //                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //                   decoration: BoxDecoration(
          //                     color: AppColors.surfaceVariant,
          //                     borderRadius: BorderRadius.circular(4),
          //                   ),
          //                   child: Text(
          //                     'Roll: $rollNo',
          //                     style: AppTextStyles.labelXs.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
          //                   ),
          //                 ),
          //                 const SizedBox(width: 8),
          //                 Text(
          //                   '$className - $sectionName',
          //                   style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
          //                 ),
          //               ],
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: AppSpacing.stackLg),

          // Image Preview Container
          Center(
            child: Column(
              children: [
                if (widget.pickedImage != null) ...[
                 
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                     
                      image: DecorationImage(
                        image: FileImage(widget.pickedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      image: hasCurrentImg
                          ? DecorationImage(
                              image: NetworkImage(ImageUrlHelper.sanitizeUrl(currentImgUrl)!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasCurrentImg
                        ? Icon(
                            Icons.person_outline_rounded,
                            size: 80,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),

          // Actions
          if (widget.isUploading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Uploading Image...'),
                ],
              ),
            )
          else ...[
            if (widget.pickedImage == null) ...[
              // Camera and Gallery buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onCapturePhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Capture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onCapturePhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Confirm upload and Cancel buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: widget.onUploadAndAssignPhoto,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successText,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton.icon(
                        onPressed: () => widget.onCapturePhoto(ImageSource.camera),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Recapture'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton.icon(
                        onPressed: widget.onDiscardPickedImage,
                        icon: const Icon(Icons.close_rounded, color: AppColors.errorText),
                        label: const Text(
                          'Discard',
                          style: TextStyle(color: AppColors.errorText),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.errorText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]
          ],
          const SizedBox(height: AppSpacing.stackLg),

          _buildSectionCard(
            title: 'Student Tags (${_assignedTags.length} allotted)',
            icon: Icons.local_offer_rounded,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_assignedTags.isEmpty)
                    const Text(
                      'No tags allotted to this student.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    )
                  else
                    ..._assignedTags.map((tag) => GestureDetector(
                          onLongPress: () => _showTagDetails(tag),
                          child: Chip(
                            label: Text(tag['name'] ?? ''),
                            avatar: const Icon(Icons.tag, size: 14, color: Colors.white),
                            backgroundColor: AppColors.primary,
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                            deleteIcon: _isTagEditing
                                ? const Icon(Icons.cancel, size: 16, color: Colors.white)
                                : null,
                            onDeleted: _isTagEditing ? () => _confirmRemoveTag(tag) : null,
                          ),
                        )),
                  IconButton(
                    icon: Icon(
                      _isTagEditing ? Icons.check_circle_outline : Icons.edit_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isTagEditing = !_isTagEditing;
                        if (!_isTagEditing) {
                          _selectedTagCategory = null;
                          _selectedTagIdToAdd = null;
                        }
                      });
                    },
                  ),
                ],
              ),
              if (_isTagEditing) ...[
                const SizedBox(height: 16),
                _buildTagPickerSection(),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.stackLg),

          // Details section title & edit mode switch (duplicated just above the fields as well for quick editing)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Details',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (!_isLoading && _errorMessage == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isEditable ? '' : 'Edit?',
                      style: AppTextStyles.labelXs.copyWith(
                        color: _isEditable ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _isEditable,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _isEditable = value;
                          if (!_isEditable) {
                            _resetForm();
                          }
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.errorText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Loading Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _buildSectionCard(
              title: 'Profile Details',
              icon: Icons.assignment_ind_rounded,
              children: [
                _buildFieldWrapper(
                  'Student Name',
                  _buildTextField(_nameController, placeholder: 'Student Name', errorText: _nameError),
                ),
                _buildFieldWrapper(
                  'School',
                  _buildDropdownField<String>(
                    value: _selectedSchoolId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not Selected')),
                      ...widget.schools.map((s) => DropdownMenuItem(
                            value: s['id']?.toString(),
                            child: Text(s['name']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: _isEditable ? (val) => setState(() => _selectedSchoolId = val) : null,
                  ),
                ),
                _buildFieldWrapper(
                  'Class',
                  _buildDropdownField<String>(
                    value: _selectedClassId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not Selected')),
                      ...widget.classes.map((c) => DropdownMenuItem(
                            value: c['id']?.toString(),
                            child: Text(c['name']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: _isEditable ? (val) => setState(() => _selectedClassId = val) : null,
                  ),
                ),
                _buildFieldWrapper(
                  'Section',
                  _buildDropdownField<String>(
                    value: _selectedSectionId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not Selected')),
                      ...widget.sections.map((s) => DropdownMenuItem(
                            value: s['id']?.toString(),
                            child: Text(s['name']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: _isEditable ? (val) => setState(() => _selectedSectionId = val) : null,
                  ),
                ),
                _buildFieldWrapper(
                  'Roll No.',
                  _buildTextField(
                    _rollNoController,
                    placeholder: 'Roll No.',
                    keyboardType: TextInputType.number,
                    errorText: _rollNoError,
                  ),
                ),
                _buildFieldWrapper(
                  'Password',
                  _buildTextField(_passwordController, placeholder: 'Password'),
                ),
                _buildFieldWrapper(
                  'Date of Birth',
                  _buildDobField(),
                ),
                _buildFieldWrapper(
                  'Gender',
                  _buildDropdownField<String>(
                    value: _selectedGender,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not Selected')),
                      ..._genders.map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g == 'male' ? 'Male' : (g == 'female' ? 'Female' : g)),
                          )),
                    ],
                    onChanged: _isEditable ? (val) => setState(() => _selectedGender = val) : null,
                  ),
                ),
                _buildFieldWrapper(
                  'Category',
                  _buildDropdownField<String>(
                    value: _selectedCategory,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not Selected')),
                      ..._categories.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase()),
                          )),
                    ],
                    onChanged: _isEditable ? (val) => setState(() => _selectedCategory = val) : null,
                  ),
                ),
                _buildFieldWrapper(
                  'FL Batch',
                  _buildDropdownField<String>(
                    value: _selectedFlBatchId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not Selected')),
                      ..._alumni.map((a) => DropdownMenuItem(
                            value: a['id']?.toString(),
                            child: Text(a['name']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: _isEditable ? (val) => setState(() => _selectedFlBatchId = val) : null,
                  ),
                ),
                _buildFieldWrapper(
                  'Father\'s Name',
                  _buildTextField(_fatherNameController, placeholder: 'Father\'s Name'),
                ),
                _buildFieldWrapper(
                  'Mother\'s Name',
                  _buildTextField(_motherNameController, placeholder: 'Mother\'s Name'),
                ),
                _buildFieldWrapper(
                  'Email Address',
                  _buildTextField(
                    _emailController,
                    placeholder: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                ),
                _buildFieldWrapper(
                  'Phone 1',
                  _buildTextField(
                    _phone1Controller,
                    placeholder: 'Phone 1',
                    keyboardType: TextInputType.phone,
                    errorText: _phone1Error,
                  ),
                ),
                _buildFieldWrapper(
                  'Phone 2',
                  _buildTextField(
                    _phone2Controller,
                    placeholder: 'Phone 2',
                    keyboardType: TextInputType.phone,
                    errorText: _phone2Error,
                  ),
                ),
                _buildFieldWrapper(
                  'Address',
                  _buildTextField(_addressController, placeholder: 'Address'),
                ),
              ],
            ),

            if (_isEditable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _isEditable = false;
                                  _resetForm();
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ]
        ],
      ),
    );
  }
}
