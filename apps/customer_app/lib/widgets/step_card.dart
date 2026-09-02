import 'package:flutter/material.dart';

/// بطاقة خطوة مرقَّمة — نفس الشكل المتكرِّر عبر شاشات الطلب متعددة
/// الخطوات (اطلب أي شيء/Taxi/حرفيون: دخول ثم عنوان ثم تفاصيل). كانت
/// مُعرَّفة محليًا بشكل مطابق حرفيًا فـ كل شاشة من الثلاث — استُخرجت
/// هنا لتفادي تكرارها فـ كل تعديل مستقبلي على شكلها.
class StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final bool isDone;
  final Widget child;

  const StepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.isDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDone
                      ? theme.colorScheme.primary
                      : Colors.black26,
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
