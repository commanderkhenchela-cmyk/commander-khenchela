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
                MerchantLogo(
                  url: merchant.logoUrl,
                  size: 40,
                  iconSize: 20,
                  borderRadius: 12,
                ),
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
