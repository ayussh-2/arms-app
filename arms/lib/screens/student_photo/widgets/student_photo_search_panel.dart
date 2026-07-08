import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../widgets/arms_dropdown_selector.dart';
import '../../../widgets/arms_picker_sheet.dart';
import '../../../widgets/arms_search_field.dart';

class StudentPhotoSearchPanel extends StatefulWidget {
  const StudentPhotoSearchPanel({
    super.key,
    required this.onSearch,
    required this.isLoading,
    required this.searchResults,
    required this.onStudentSelected,
    required this.onLoadMore,
    required this.isLoadingMore,
    required this.hasMore,
    required this.initialQuery,
    required this.schools,
    required this.classes,
    required this.sections,
    required this.selectedSchoolName,
    required this.selectedClassName,
    required this.selectedSectionName,
    required this.havingPhoto,
    required this.onShowSchoolPicker,
    required this.onShowClassPicker,
    required this.onShowSectionPicker,
    required this.onHavingPhotoChanged,
    required this.onClearFilters,
    required this.onClearSchool,
    required this.onClearClass,
    required this.onClearSection,
    required this.onClearHavingPhoto,
  });

  final ValueChanged<String> onSearch;
  final bool isLoading;
  final List<Map<String, dynamic>> searchResults;
  final ValueChanged<Map<String, dynamic>> onStudentSelected;
  final VoidCallback onLoadMore;
  final bool isLoadingMore;
  final bool hasMore;
  final String initialQuery;

  final List<dynamic> schools;
  final List<dynamic> classes;
  final List<dynamic> sections;
  final String? selectedSchoolName;
  final String? selectedClassName;
  final String? selectedSectionName;
  final bool? havingPhoto;

  final VoidCallback onShowSchoolPicker;
  final VoidCallback onShowClassPicker;
  final VoidCallback onShowSectionPicker;
  final ValueChanged<bool?> onHavingPhotoChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onClearSchool;
  final VoidCallback onClearClass;
  final VoidCallback onClearSection;
  final VoidCallback onClearHavingPhoto;

  @override
  State<StudentPhotoSearchPanel> createState() => _StudentPhotoSearchPanelState();
}

class _StudentPhotoSearchPanelState extends State<StudentPhotoSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _isFiltersExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  void _onChanged(String val) {
    setState(() {}); // Re-build to show/hide the clear suffix icon
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onSearch(val);
    });
  }

  void _triggerSearch() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    widget.onSearch(_controller.text);
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
    });
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    widget.onSearch('');
  }

  Widget _buildStudentTile(Map<String, dynamic> student) {
    final name = student['name'] ?? 'No Name';
    final rollNo = student['roll_no'] ?? 'No Roll No';
    final currentImgUrl = student['image_url'] as String?;
    final hasCurrentImg = currentImgUrl != null && currentImgUrl.isNotEmpty;

    final className = student['class']?['name']?.toString() ?? 'Unknown Class';
    final sectionName = student['section']?['name']?.toString() ?? 'Unknown Section';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceVariant,
            image: hasCurrentImg
                ? DecorationImage(
                    image: NetworkImage(ImageUrlHelper.sanitizeUrl(currentImgUrl)!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !hasCurrentImg
              ? const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.onSurfaceVariant,
                )
              : null,
        ),
        title: Text(
          name,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Roll No: $rollNo',
              style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
            ),
            Text(
              'Class: $className ($sectionName)',
              style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        onTap: () => widget.onStudentSelected(student),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (widget.isLoading && widget.searchResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (widget.searchResults.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No students found',
                style: AppTextStyles.headerSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with a different name or roll number',
                style: AppTextStyles.labelXs,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final isSearchingFiltered = _controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isLoading) ...[
          const LinearProgressIndicator(
            backgroundColor: AppColors.cardSurface,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            isSearchingFiltered
                ? 'Search Results (${widget.searchResults.length})'
                : 'All Students',
            style: AppTextStyles.labelXsUppercase.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: widget.searchResults.length + (widget.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == widget.searchResults.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: widget.isLoadingMore
                          ? const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                );
              }
              final student = widget.searchResults[index];
              return _buildStudentTile(student);
            },
          ),
        ),
      ],
    );
  }

  void _showHavingPhotoPicker() {
    final items = [
      {'id': 'all', 'name': 'All Students'},
      {'id': 'with', 'name': 'With Photo'},
      {'id': 'without', 'name': 'Without Photo'},
    ];
    ArmsPickerSheet.show<Map<String, String>>(
      context: context,
      title: 'Photo Status',
      items: items,
      itemLabel: (item) => item['name']!,
      onItemSelected: (item) {
        if (item['id'] == 'all') {
          widget.onHavingPhotoChanged(null);
        } else if (item['id'] == 'with') {
          widget.onHavingPhotoChanged(true);
        } else {
          widget.onHavingPhotoChanged(false);
        }
      },
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onClear}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.roundFull),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChipsList() {
    final List<Widget> chips = [];
    if (widget.selectedSchoolName != null) {
      chips.add(_buildFilterChip(
        label: 'School: ${widget.selectedSchoolName}',
        onClear: widget.onClearSchool,
      ));
    }
    if (widget.selectedClassName != null) {
      chips.add(_buildFilterChip(
        label: 'Class: ${widget.selectedClassName}',
        onClear: widget.onClearClass,
      ));
    }
    if (widget.selectedSectionName != null) {
      chips.add(_buildFilterChip(
        label: 'Section: ${widget.selectedSectionName}',
        onClear: widget.onClearSection,
      ));
    }
    if (widget.havingPhoto != null) {
      String status = widget.havingPhoto == true ? 'With Photo' : 'Without Photo';
      chips.add(_buildFilterChip(
        label: 'Status: $status',
        onClear: widget.onClearHavingPhoto,
      ));
    }
    return chips;
  }

  Widget _buildFiltersSection(bool hasActiveFilters) {
    String photoStatusText = 'All Students';
    if (widget.havingPhoto == true) {
      photoStatusText = 'With Photo';
    } else if (widget.havingPhoto == false) {
      photoStatusText = 'Without Photo';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isFiltersExpanded = !_isFiltersExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(AppRadius.roundEight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FILTERS',
                        style: AppTextStyles.labelXsUppercase.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isFiltersExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasActiveFilters)
              GestureDetector(
                onTap: widget.onClearFilters,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'Reset Filters',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_isFiltersExpanded) ...[
          const SizedBox(height: 8),
          ArmsDropdownSelector(
            value: widget.selectedSchoolName,
            placeholder: 'Select School',
            onTap: widget.onShowSchoolPicker,
            icon: Icons.business_rounded,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ArmsDropdownSelector(
                  value: widget.selectedClassName,
                  placeholder: 'Class',
                  onTap: widget.onShowClassPicker,
                  icon: Icons.class_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ArmsDropdownSelector(
                  value: widget.selectedSectionName,
                  placeholder: 'Section',
                  onTap: widget.onShowSectionPicker,
                  icon: Icons.grid_view_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ArmsDropdownSelector(
            value: photoStatusText,
            placeholder: 'Photo Status',
            onTap: _showHavingPhotoPicker,
            icon: Icons.photo_library_outlined,
          ),
        ] else if (hasActiveFilters) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _buildFilterChipsList(),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = widget.selectedSchoolName != null ||
        widget.selectedClassName != null ||
        widget.selectedSectionName != null ||
        widget.havingPhoto != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginPage,
        vertical: AppSpacing.stackLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          ArmsSearchField(
            key: const ValueKey('search_text_field'),
            controller: _controller,
            focusNode: _focusNode,
            hintText: 'Search student by name or roll number...',
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _triggerSearch(),
            onChanged: _onChanged,
            onClear: _clearSearch,
            fillColor: AppColors.cardSurface,
            hasBorder: true,
          ),
          const SizedBox(height: 16),

          // Filters Section
          _buildFiltersSection(hasActiveFilters),
          const SizedBox(height: 16),

          // Search content area (Welcome Guide or Search Results)
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }
}
