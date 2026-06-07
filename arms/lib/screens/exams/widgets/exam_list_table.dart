import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'exam_card.dart';

class ExamListTable extends StatelessWidget {
  final List<Map<String, dynamic>> exams;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final VoidCallback onLoadMore;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>) onDownloadReport;

  const ExamListTable({
    super.key,
    required this.exams,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onLoadMore,
    required this.onTap,
    required this.onDownloadReport,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginPage, 0, AppSpacing.marginPage, 120),
      itemCount: exams.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == exams.length) {
          // loading indicator for pagination
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final exam = exams[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
          child: ExamCard(
            exam: exam,
            onTap: () => onTap(exam),
            onDownloadReport: () => onDownloadReport(exam),
          ),
        );
      },
    );
  }
}
