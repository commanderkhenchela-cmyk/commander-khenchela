import 'package:flutter/material.dart';

import '../models/merchant.dart';
import '../theme/design_tokens.dart';
import 'merchant_logo.dart';

/// بطاقة محل مصغّرة لقسم أفقي قابل للتمرير (مميزة / الأكثر طلبًا /
/// المضافة حديثًا داخل صفحة تصنيف). Component مستقل وقابل للاختبار
/// المباشر، راجع merchant_mini_card_test.dart.
///
/// نفس إصلاح Overflow المطبَّق في CategoryGridTile: اسم المحل داخل
/// Expanded (لا Column عادي) — يمنع الفيضان بنيويًا مهما طال الاسم أو
/// كبر خط النظام، بدل الاعتماد فقط على ارتفاع محسوب يدويًا.
class MerchantMiniCard extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;

  const MerchantMiniCard({
    super.key,
    required this.merchant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 128,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoWithStatusDot(merchant: merchant),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    merchant.storeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شعار المحل + نقطة حالة صغيرة على زاويته (أخضر=مفتوح، أحمر=مغلق) —
/// لا تُعرض إلا عندما تُعرَف الحالة فعليًا (merchant.isOpenNow != null)،
/// تمامًا كنفس شرط OpenStatusBadge. نقطة ثابتة الحجم (لا نص) عمدًا: لا
/// تضيف أي ارتفاع للعمود (Stack يأخذ حجم الشعار نفسه)، فتبقى البطاقة
/// آمنة من Overflow عند تكبير خط النظام (راجع merchant_mini_card_test.dart)
/// بدل إضافة سطر شارة كامل في مساحة 128px الضيقة.
class _LogoWithStatusDot extends StatelessWidget {
  final Merchant merchant;

  const _LogoWithStatusDot({required this.merchant});

  @override
  Widget build(BuildContext context) {
    final isOpen = merchant.isOpenNow;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        MerchantLogo(
          url: merchant.logoUrl,
          size: 40,
          iconSize: 20,
          borderRadius: 12,
        ),
        if (isOpen != null)
          Positioned(
            bottom: -1,
            left: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                // أخضر/أحمر دلاليان ثابتان (AppColorsX.success/danger)،
                // وليس colorScheme.primary/error — راجع التعليق في
                // open_status_badge.dart لسبب هذا التحديد تحديدًا.
                color: isOpen
                    ? Theme.of(context).colorScheme.success
                    : Theme.of(context).colorScheme.danger,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
