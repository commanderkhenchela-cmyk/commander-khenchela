import 'package:flutter/material.dart';

/// حقل بحث موحَّد الشكل، يُستخدم داخل شاشة تصنيف واحد (بحث محلي ضمن
/// القائمة المحمَّلة) وداخل شاشة البحث العامة (SearchScreen). قابلية
/// إعادة استخدام بدل تكرار نفس الـ Widget الخاص في أكثر من شاشة.
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool autofocus;

  const SearchField({
    super.key,
    required this.controller,
    this.hintText = 'ابحث عن محل...',
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clear,
                ),
        ),
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
