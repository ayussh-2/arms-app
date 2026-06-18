import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_url_helper.dart';

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
  });

  final ValueChanged<String> onSearch;
  final bool isLoading;
  final List<Map<String, dynamic>> searchResults;
  final ValueChanged<Map<String, dynamic>> onStudentSelected;
  final VoidCallback onLoadMore;
  final bool isLoadingMore;
  final bool hasMore;
  final String initialQuery;

  @override
  State<StudentPhotoSearchPanel> createState() => _StudentPhotoSearchPanelState();
}

class _StudentPhotoSearchPanelState extends State<StudentPhotoSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginPage,
        vertical: AppSpacing.stackLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            key: const ValueKey('search_text_field'),
            focusNode: _focusNode,
            controller: _controller,
            style: AppTextStyles.bodyMedium,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _triggerSearch(),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.cardSurface,
              hintText: 'Search student by name or roll number...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                      onPressed: _clearSearch,
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.roundFull),
                borderSide: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.roundFull),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
            onChanged: _onChanged,
          ),
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
