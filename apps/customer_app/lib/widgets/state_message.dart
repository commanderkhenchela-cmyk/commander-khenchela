import 'package:flutter/material.dart';

/// حالة "استبدال كامل للمحتوى" موحَّدة — خطأ تحميل (مع زر إعادة محاولة)
/// أو قائمة فارغة بلا أي RefreshIndicator محيط (شاشة تفاصيل واحدة، أو
/// شاشة بلا سحب-للتحديث أصلًا). كانت مُعاد اختراعها بأسماء مختلفة
/// (_CenterMessage فـ favorites_screen.dart، _StateMessage فـ
/// all_categories_screen.dart، _ErrorState فـ my_orders_screen.dart
/// وأخواتها) بنفس التصميم بالضبط — هذا هو الأصل المشترك الآن.
///
/// بخلاف [EmptyListMessage] (مصمَّمة خصّيصًا لتكون عنصر ListView أول
/// تحت RefreshIndicator فعّال — راجع تعليقها)، هذه الودجة تُوسِّط
/// نفسها (Center) وتحلّ محلّ المحتوى بالكامل — لا تُستخدَم داخل
/// RefreshIndicator (تُلغي فائدته أصلًا لأنها ليست قائمة قابلة للسحب).
class StateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const StateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
