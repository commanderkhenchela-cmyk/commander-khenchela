import 'package:flutter/material.dart';

/// رأس بصري موحَّد لشاشات الطلب الثلاث (اطلب أي شيء/Taxi/حرفيون) —
/// أيقونة دائرية بلون العلامة فوق نص الشرح، بدل نص مجرَّد بلا أي هوية
/// بصرية أعلى الشاشة. نفس لغة "أيقونة داخل دائرة ملوَّنة" المستخدَمة
/// أصلًا فـ بطاقات الخدمات بالرئيسية (ServiceIcon) وبطاقات الطلبات.
class RequestIntroHeader extends StatelessWidget {
  final IconData icon;
  final String text;

  const RequestIntroHeader({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
