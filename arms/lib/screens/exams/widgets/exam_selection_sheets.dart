import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

void showExamMultiSelectSheet({
  required BuildContext context,
  required String title,
  required List<Map<String, dynamic>> options,
  required Set<String> selectedIds,
  required VoidCallback onSelectionChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final isAllSelected = selectedIds.length == options.length;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: Text(
                      'All',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    value: isAllSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedIds.addAll(options.map((e) => e['id'] as String));
                        } else {
                          selectedIds.clear();
                        }
                      });
                      onSelectionChanged();
                    },
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final id = opt['id'] as String;
                        final isSelected = selectedIds.contains(id);

                        return CheckboxListTile(
                          title: Text(
                            opt['name'] ?? '',
                            style: AppTextStyles.bodyMedium,
                          ),
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            });
                            onSelectionChanged();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showExamSingleSelectSheet({
  required BuildContext context,
  required String title,
  required Map<String, dynamic>? currentValue,
  required List<Map<String, dynamic>> options,
  required ValueChanged<Map<String, dynamic>> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = opt['id'] == currentValue?['id'];
                    return ListTile(
                      title: Text(
                        opt['name'] ?? '',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : AppColors.textMain,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check,
                                color: AppColors.primary,
                              )
                              : null,
                      onTap: () {
                        onSelected(opt);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showSubjectSelectSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> subjectsLookup,
  required List<Map<String, dynamic>> selectedSubjects,
  required Map<String, TextEditingController> subjectMarkControllers,
  required VoidCallback onSelectionChanged,
}) {
  String searchPattern = '';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = subjectsLookup.where((sub) {
            final name = (sub['name'] as String? ?? '').toLowerCase();
            final code = (sub['code'] as String? ?? '').toLowerCase();
            final q = searchPattern.toLowerCase();
            return q.isEmpty || name.contains(q) || code.contains(q);
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Subjects',
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search subjects...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchPattern = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final sub = filtered[index];
                        final subId = sub['id'] as String;
                        final isSelected = selectedSubjects.any((s) => s['id'] == subId);

                        return ListTile(
                          title: Text(
                            sub['name'] ?? '',
                            style: AppTextStyles.bodyMedium,
                          ),
                          subtitle: sub['code'] != null 
                              ? Text(sub['code'] as String, style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary)) 
                              : null,
                          leading: Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  if (!isSelected) {
                                    selectedSubjects.add(sub);
                                    if (!subjectMarkControllers.containsKey(subId)) {
                                      subjectMarkControllers[subId] = TextEditingController(text: '100');
                                    }
                                  }
                                } else {
                                  selectedSubjects.removeWhere((s) => s['id'] == subId);
                                }
                              });
                              onSelectionChanged();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
