import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';

/// شارة صغيرة "مفتوح الآن" / "مغلق الآن" — تُستخدم في بطاقة المحل الكاملة
/// (MerchantCard، القوائم العمودية). لا تُعرض أبدًا إلا عندما تُعرَف
/// الحالة فعليًا (merchant.isOpenNow != null من طرف الشاشة المستدعية)،
/// أبدًا كتخمين. البطاقة المصغّرة (MerchantMiniCard، أقسام الصفحة
/// الرئيسية الأفقية) تستخدم نقطة ملوَّنة صغيرة على الشعار بدل هذه الشارة
/// كاملة النص — راجع merchant_mini_card.dart، ضيق المساحة هناك (128px)
/// لا يتسع لنص إضافي بأمان مع تكبير خط النظام.
class OpenStatusBadge extends StatelessWidget {
  final bool isOpen;

  const OpenStatusBadge({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // أخضر/أحمر دلاليان ثابتان (AppColorsX.success/danger) — وليس
    // colorScheme.primary/error: كلاهما قابل لتخصيص الأدمن ديناميكيًا عبر
    // BrandingService (لون العلامة التجارية الفعلي لهذا التطبيق أحمر/وردي
    // في الإنتاج الحالي!) — استخدامهما كان يجعل "مفتوح" يظهر بلون العلامة
    // التجارية الأحمر بدل أخضر حقيقي، وهو بالضبط الخلل الذي رآه المستخدم.
    // هذه الشارة يجب أن تبقى أخضر/أحمر عالميًا مفهومَين بصرف النظر عن
    // هوية العلامة التجارية.
    final color = isOpen ? theme.colorScheme.success : theme.colorScheme.danger;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          isOpen
              ? AppLocalizations.of(context).openNowSectionTitle
              : AppLocalizations.of(context).closedNowLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
