import 'package:flutter/material.dart';

import '../services/branding_service.dart';

/// شعار التطبيق — يعرض الصورة المرفوعة من لوحة الإدارة (BrandingService)
/// إن وُجدت، وإلا أيقونة افتراضية. مستخدَم في أكثر من شاشة، مركزيًا هنا
/// حتى يتحدَّث الشعار في كل مكان فور تغييره من الإدارة دون تكرار الكود.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppLogo({
    super.key,
    this.size = 96,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoUrl = BrandingService.logoUrl;
    final bg = backgroundColor ?? theme.colorScheme.primary;
    final fg = iconColor ?? Colors.white;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: logoUrl == null ? bg : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: logoUrl != null
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.storefront_rounded, color: fg, size: size * 0.5),
            )
          : Icon(Icons.storefront_rounded, color: fg, size: size * 0.5),
    );
  }
}
