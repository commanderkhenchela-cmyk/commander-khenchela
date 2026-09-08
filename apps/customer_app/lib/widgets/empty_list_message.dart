import 'package:flutter/material.dart';

/// حالة فارغة موحَّدة لقوائم قابلة لسحب-التحديث (RefreshIndicator) —
/// أيقونة رمادية خافتة + رسالة، نفس لغة _CenterMessage فـ
/// favorites_screen.dart، بدل نص وحيد بلا سياق بصري. تُوضَع كعنصر أول
/// داخل ListView (لا Center/Expanded) حتى يبقى RefreshIndicator فعّالًا
/// حتى مع قائمة فارغة.
class EmptyListMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyListMessage({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Icon(
            icon,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
