import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_radius.dart';
import '../../../widgets/components/arms_search_field.dart';
import '../../../widgets/components/arms_avatar.dart';

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
          ArmsSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
            hintText: 'Search Student...',
            fillColor: AppColors.cardSurface,
            hasBorder: false,
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
                    color: Colors.black.withValues(alpha: 0.05),
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
                  final imgUrl = s['image_url'] as String?;
                  return ListTile(
                    leading: ArmsAvatar(
                      imageUrl: imgUrl,
                      name: name,
                      radius: 16,
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
      final name = selectedStudent?['name'] as String? ?? '';
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
                ArmsAvatar(
                  imageUrl: studentImg,
                  name: name,
                  radius: 20,
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
