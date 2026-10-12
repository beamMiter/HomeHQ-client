import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class SearchBarField extends StatelessWidget {
  const SearchBarField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  /// Defaults to the translated "Search…".
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText ?? context.l10n.commonSearch,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
      ),
    );
  }
}
