import 'package:flutter/material.dart';

/// حالة فارغة/خطأ موحَّدة لقوائم قابلة لسحب-التحديث (RefreshIndicator) —
/// أيقونة + رسالة، تُوضَع كعنصر أول داخل ListView (لا Center) حتى يبقى
/// RefreshIndicator فعّالًا حتى مع قائمة فارغة أو حالة خطأ — هذا بالضبط
/// ما يميّزها عن StateMessage (تُوسِّط نفسها Center، تُستخدَم فقط حين لا
/// يوجد RefreshIndicator محيط أصلًا، مثل notifications_screen.dart).
///
/// كانت هذه الحالة (خصوصًا حالة الخطأ) مُعاد اختراعها بالحرف فـ 3 شاشات
/// (home_screen، ride_requests_home_screen، delivery_requests_home_screen)
/// — هذا هو الأصل المشترك الآن.
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
    return Column(
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: Colors.black45),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}
