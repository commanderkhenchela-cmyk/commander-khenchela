import 'package:flutter/material.dart';

import '../models/merchant.dart';
import 'favorite_button.dart';
import 'merchant_logo.dart';
import 'open_status_badge.dart';

/// بطاقة محل عمودية كاملة (قائمة "كل المحلات" في شاشة التصنيف، وأي قائمة
/// عمودية أخرى). Component عام وقابل لإعادة الاستخدام — مستخرج من
/// MerchantsScreen حتى تستخدمه أيضًا شاشات أخرى (مثل نتائج البحث) بدون
/// تكرار نفس الكود.
class MerchantCard extends StatelessWidget {
  final Merchant merchant;
  final String? distanceLabel;
  final VoidCallback onTap;

  const MerchantCard({
    super.key,
    required this.merchant,
    required this.onTap,
    this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              MerchantLogo(url: merchant.logoUrl, size: 56, iconSize: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Builder(
                      builder: (context) {
                        final chips = _metaChips(theme);
                        if (chips.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              for (var i = 0; i < chips.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                chips[i],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              FavoriteButton(merchantId: merchant.id),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عناصر السطر الثاني (بلدية / مسافة / حالة فتح) — مبنيّة كقائمة حتى
  /// نتحكّم في المسافات بينها بدون تكرار شروط. اسم البلدية داخل
  /// Flexible مع Ellipsis لتفادي فيضان أفقي إن اجتمعت الثلاثة عناصر في
  /// سطر ضيق (نفس منطق حماية الـ Overflow المتّبع في بقية الشاشة).
  List<Widget> _metaChips(ThemeData theme) {
    final chips = <Widget>[];

    if (merchant.communeName != null) {
      chips.add(
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  merchant.communeName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (distanceLabel != null) {
      chips.add(
        Text(
          distanceLabel!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    if (merchant.isOpenNow != null) {
      chips.add(OpenStatusBadge(isOpen: merchant.isOpenNow!));
    }

    return chips;
  }
}
