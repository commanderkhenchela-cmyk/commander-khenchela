import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// شعار محل داخل بطاقة (عمودية أو أفقية مصغّرة) — يعرض الصورة الحقيقية
/// المرفوعة من التاجر إن وُجدت (merchant.logoUrl)، وإلا الأيقونة الرمزية
/// الاحتياطية الحالية. نفس السلوك أيضًا إن فشل تحميل الصورة (رابط معطوب،
/// لا إنترنت) — لا تُترك الخانة فارغة أو مكسورة أبدًا. يستخدم
/// CachedNetworkImage (لا Image.network) لأن نفس شعار المحل يتكرر عبر
/// شاشات كثيرة (الرئيسية/البحث/قائمة المحلات) — تخزين مؤقت على القرص
/// يمنع إعادة تنزيله في كل مرة يظهر بها.
class MerchantLogo extends StatelessWidget {
  final String? url;
  final double size;
  final double iconSize;
  final double borderRadius;

  const MerchantLogo({
    super.key,
    required this.url,
    required this.size,
    required this.iconSize,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoUrl = url;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: logoUrl == null
          ? Icon(
              Icons.storefront_rounded,
              color: theme.colorScheme.primary,
              size: iconSize,
            )
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Icon(
                Icons.storefront_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                size: iconSize,
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.storefront_rounded,
                color: theme.colorScheme.primary,
                size: iconSize,
              ),
            ),
    );
  }
}
