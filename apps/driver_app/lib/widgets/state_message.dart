import 'package:flutter/material.dart';

/// حالة "استبدال كامل للمحتوى" موحَّدة — خطأ تحميل (مع زر إعادة محاولة
/// اختياري) أو قائمة فارغة بلا أي RefreshIndicator محيط (مثل
/// notifications_screen.dart، التي لا تدعم سحب-للتحديث أصلًا).
///
/// بخلاف [EmptyListMessage] (مصمَّمة خصّيصًا لتكون عنصر ListView أول تحت
/// RefreshIndicator فعّال)، هذه الودجة تُوسِّط نفسها (Center) وتحلّ محلّ
/// المحتوى بالكامل.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.black45),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
