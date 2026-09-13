import 'package:flutter/material.dart';

/// بطاقة قسم عامة (عنوان + أيقونة + أسطر نص + إجراء اختياري) — مستخرَجة
/// من ثلاث نسخ خاصة مطابقة بالحرف (job_detail_screen، ride_job_detail_
/// screen، delivery_request_job_detail_screen)، كل واحدة كانت تعرّف
/// _SectionCard محليًا بنفس البنية والقيم تمامًا (تحقّق بالمقارنة
/// المباشرة قبل الاستخراج — لا فرق سوى التفاف السطر).
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget? action;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}
