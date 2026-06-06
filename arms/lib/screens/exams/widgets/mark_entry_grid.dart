import 'package:flutter/material.dart';
import 'student_mark_card.dart';

class MarkEntryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> subjects;
  final Map<String, Map<String, TextEditingController>> controllers;
  final Map<String, ValueNotifier<bool>> absentNotifiers;
  final Map<String, ValueNotifier<String>> statusNotifiers;
  final bool isEditing;
  final List<FocusNode>? focusNodes;
  final double itemWidth;
  final int currentPage;
  final int pageSize;
  final String? currentEditingStudentId;
  final void Function(String studentId, String subjectId, String val) onMarkChanged;
  final void Function(String studentId) onAbsentToggle;
  final void Function(String studentId) onStatusCycle;
  final VoidCallback? onNext;

  const MarkEntryGrid({
    super.key,
    required this.students,
    required this.subjects,
    required this.controllers,
    required this.absentNotifiers,
    required this.statusNotifiers,
    required this.isEditing,
    this.focusNodes,
    required this.itemWidth,
    required this.currentPage,
    required this.pageSize,
    this.currentEditingStudentId,
    required this.onMarkChanged,
    required this.onAbsentToggle,
    required this.onStatusCycle,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final studentId = student['id'] as String;
        final ctrlMap = controllers[studentId] ?? {};
        final absentNotifier = absentNotifiers[studentId] ?? ValueNotifier<bool>(false);
        final statusNotifier = statusNotifiers[studentId] ?? ValueNotifier<String>('NORMAL');
        final slNo = (currentPage * pageSize) + index + 1;
        final isStudentEditing = isEditing && currentEditingStudentId == studentId;

        return Padding(
          key: ValueKey(studentId),
          padding: const EdgeInsets.only(bottom: 12),
          child: StudentMarkCard(
            student: student,
            slNo: slNo,
            absentNotifier: absentNotifier,
            statusNotifier: statusNotifier,
            controllers: ctrlMap,
            subjects: subjects,
            isEditing: isStudentEditing,
            focusNodes: isStudentEditing ? focusNodes : null,
            itemWidth: itemWidth,
            onAbsentToggled: () => onAbsentToggle(studentId),
            onStatusChanged: () => onStatusCycle(studentId),
            onMarkChanged: (subId, val) => onMarkChanged(studentId, subId, val),
            onNext: onNext,
          ),
        );
      },
    );
  }
}
