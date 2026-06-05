import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/image_url_helper.dart';

class StudentSearchSection extends StatelessWidget {
  final Map<String, dynamic>? selectedStudent;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Map<String, dynamic>> filteredStudents;
  final bool isSearching;
  final ValueChanged<Map<String, dynamic>> onStudentSelected;
  final VoidCallback onStudentCleared;

  const StudentSearchSection({
    super.key,
    required this.selectedStudent,
    required this.searchController,
    required this.onSearchChanged,
    required this.filteredStudents,
    required this.isSearching,
    required this.onStudentSelected,
    required this.onStudentCleared,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedStudent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STUDENT', style: AppTextStyles.labelXsUppercase),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.roundFull),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                hintText: 'Search Student...',
                hintStyle: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          if (isSearching && filteredStudents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.roundTwelve),
                border: Border.all(color: AppColors.outlineMediumLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredStudents.length,
                itemBuilder: (ctx, idx) {
                  final s = filteredStudents[idx];
                  final name = s['name'] as String? ?? '';
                  final avatarText = name.isNotEmpty ? name[0] : 'S';
                  final imgUrl = s['image_url'] as String?;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: (imgUrl != null && ImageUrlHelper.sanitizeUrl(imgUrl) != null)
                          ? NetworkImage(ImageUrlHelper.sanitizeUrl(imgUrl)!)
                          : null,
                      child: (imgUrl == null || ImageUrlHelper.sanitizeUrl(imgUrl) == null) ? Text(avatarText) : null,
                    ),
                    title: Text(name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text('Roll No: ${s['roll_no'] ?? ''}', style: AppTextStyles.labelXs),
                    onTap: () => onStudentSelected(s),
                  );
                },
              ),
            ),
          ] else if (isSearching && filteredStudents.isEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('No students found', style: AppTextStyles.labelXs),
            ),
          ],
        ],
      );
    } else {
      final studentImg = selectedStudent?['image_url'] as String?;
      final hasImg = studentImg != null && studentImg.trim().isNotEmpty;
      final name = selectedStudent?['name'] as String? ?? '';
      final avatarText = name.isNotEmpty ? name[0] : 'S';
      final rollNoVal = selectedStudent?['roll_no']?.toString();
      final hasRollNo = rollNoVal != null && rollNoVal.trim().isNotEmpty && rollNoVal != 'null';
      final rollNoDisplay = hasRollNo ? 'Roll No: $rollNoVal' : 'Roll No: N/A';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECTED STUDENT', style: AppTextStyles.labelXsUppercase),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
              border: Border.all(color: AppColors.outlineLight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceVariant,
                  backgroundImage: (hasImg && ImageUrlHelper.sanitizeUrl(studentImg) != null)
                      ? NetworkImage(ImageUrlHelper.sanitizeUrl(studentImg)!)
                      : null,
                  child: (!hasImg || ImageUrlHelper.sanitizeUrl(studentImg) == null) ? Text(avatarText) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Text(rollNoDisplay, style: AppTextStyles.labelXs),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.errorText),
                  onPressed: onStudentCleared,
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}
