import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'arms_input_field.dart';

/// A standard search field wrapper around ArmsInputField.
/// Adds a search prefix icon and an automatic clear suffix button.
class ArmsSearchField extends StatefulWidget {
  const ArmsSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction = TextInputAction.search,
    this.onClear,
    this.fillColor = AppColors.cardSurface,
    this.hasBorder = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onClear;
  final Color? fillColor;
  final bool hasBorder;

  @override
  State<ArmsSearchField> createState() => _ArmsSearchFieldState();
}

class _ArmsSearchFieldState extends State<ArmsSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArmsInputField(
      controller: widget.controller,
      hintText: widget.hintText,
      prefixIcon: Icons.search,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      fillColor: widget.fillColor,
      hasBorder: widget.hasBorder,
      suffixIcon: widget.controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
              onPressed: () {
                widget.controller.clear();
                if (widget.onClear != null) {
                  widget.onClear!();
                } else if (widget.onChanged != null) {
                  widget.onChanged!('');
                }
              },
            )
          : null,
    );
  }
}
