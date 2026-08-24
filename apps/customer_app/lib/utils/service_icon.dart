import 'package:flutter/material.dart';

/// أيقونة Material احترافية موحَّدة لكل خدمة، بدل عرض الإيموجي الخام
/// كواجهة نهائية — راجع services.icon بقاعدة البيانات: يبقى إيموجي هناك
/// (يعرضه الأدمن فقط كمرجع/احتياطي)، لكن الواجهة تعرض دائمًا أيقونة من
/// نفس نظام الأيقونات المستخدَم في بقية التطبيق (Icons.* المدمجة في
/// Flutter، نفس فلسفة MerchantCategoryIcon تمامًا). التطابق بـslug ثابت
/// (وليس بالاسم/الإيموجي) لأن قائمة الخدمات مغلقة ومعروفة مسبقًا —
/// راجع تعليق migration 20260824000000_services.sql.
class ServiceIcon {
  const ServiceIcon._();

  static const IconData _fallback = Icons.apps_rounded;

  static const Map<String, IconData> _bySlug = {
    'marketplace': Icons.shopping_bag_rounded,
    'restaurants': Icons.restaurant_rounded,
    'taxi': Icons.local_taxi_rounded,
    'delivery': Icons.local_shipping_rounded,
    'craftsmen': Icons.build_rounded,
  };

  static IconData iconFor(String slug) => _bySlug[slug] ?? _fallback;
}
