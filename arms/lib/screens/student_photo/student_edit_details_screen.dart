import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/graphql/queries.dart';
import '../../../widgets/arms_snackbar.dart';
import '../../../widgets/arms_top_app_bar.dart';

class StudentEditDetailsScreen extends StatefulWidget {
  final String studentId;
  final String organisationId;
  final List<dynamic> schools;
  final List<dynamic> classes;
  final List<dynamic> sections;

  const StudentEditDetailsScreen({
    super.key,
    required this.studentId,
    required this.organisationId,
    required this.schools,
    required this.classes,
    required this.sections,
  });

  @override
  State<StudentEditDetailsScreen> createState() => _StudentEditDetailsScreenState();
}

class _StudentEditDetailsScreenState extends State<StudentEditDetailsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

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
    try {
      final client = GraphQLProvider.of(context).value;

      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.getStudentDetails),
          variables: {
            'id': widget.studentId,
            'organisationId': widget.organisationId,
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

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }
      if (alumniResult.hasException) {
        throw Exception(alumniResult.exception.toString());
      }

      final student = result.data?['getStudentDetails'];
      final alumniList = alumniResult.data?['getAlumni'] as List? ?? [];

      if (student != null) {
        setState(() {
          _studentData = Map<String, dynamic>.from(student);
          _alumni = List<Map<String, dynamic>>.from(
            alumniList.map((a) => Map<String, dynamic>.from(a as Map)),
          );

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

          _isLoading = false;
        });
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
      _errorMessage = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;

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
            'id': widget.studentId,
            'organisationId': widget.organisationId,
            'input': input,
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      if (mounted) {
        ArmsSnackbar.showSuccess(context, 'Student details updated successfully!');
        Navigator.of(context).pop(true);
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
      fillColor: AppColors.cardSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.15), width: 1),
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
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMain),
      decoration: _getInputDecoration(hintText: placeholder, errorText: errorText),
    );
  }

  Widget _buildDobField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: IgnorePointer(
        child: TextField(
          controller: _dobController,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMain),
          decoration: _getInputDecoration(hintText: 'yyyy-mm-dd').copyWith(
            suffixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hintText,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        padding: EdgeInsets.zero,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMain),
        decoration: _getInputDecoration(hintText: hintText),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(
        title: "Edit Student Details",
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.errorText),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.marginPage),
                  child: Column(
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
                          onChanged: (val) => setState(() => _selectedSchoolId = val),
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
                          onChanged: (val) => setState(() => _selectedClassId = val),
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
                          onChanged: (val) => setState(() => _selectedSectionId = val),
                        ),
                      ),
                      _buildFieldWrapper(
                        'Admission No. / Roll No.',
                        _buildTextField(_rollNoController,
                            placeholder: 'Admission No. / Roll No.', keyboardType: TextInputType.number, errorText: _rollNoError),
                      ),
                      _buildFieldWrapper(
                        'Father Name',
                        _buildTextField(_fatherNameController),
                      ),
                      _buildFieldWrapper(
                        'Mother Name',
                        _buildTextField(_motherNameController),
                      ),
                      _buildFieldWrapper(
                        'Date of Birth',
                        _buildDobField(),
                      ),
                      _buildFieldWrapper(
                        'Email',
                        _buildTextField(_emailController, keyboardType: TextInputType.emailAddress, errorText: _emailError),
                      ),
                      _buildFieldWrapper(
                        'Password',
                        _buildTextField(_passwordController),
                      ),
                      _buildFieldWrapper(
                        'Phone 1',
                        _buildTextField(_phone1Controller, keyboardType: TextInputType.phone, errorText: _phone1Error),
                      ),
                      _buildFieldWrapper(
                        'Phone 2',
                        _buildTextField(_phone2Controller, keyboardType: TextInputType.phone, errorText: _phone2Error),
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
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
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
                          onChanged: (val) => setState(() => _selectedGender = val),
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
                          onChanged: (val) => setState(() => _selectedFlBatchId = val),
                        ),
                      ),
                      _buildFieldWrapper(
                        'Address',
                        _buildTextField(_addressController),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
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
                    ],
                  ),
                ),
    );
  }
}
