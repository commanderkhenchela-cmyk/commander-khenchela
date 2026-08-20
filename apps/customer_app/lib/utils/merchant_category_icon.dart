import 'package:flutter/material.dart';

import '../models/merchant_category.dart';

/// يحوّل تصنيف محل (اسم + إيموجي قادمَين من لوحة الإدارة) إلى أيقونة
/// Material احترافية ولون مميّز — بدون أي ربط يدوي بمعرّف تصنيف معيّن
/// داخل الشاشة. عندما تُضيف الإدارة تصنيفًا جديدًا، تُطابَق أيقونته
/// تلقائيًا حسب الإيموجي المُدخَل أو أقرب كلمة في الاسم، دون الحاجة لأي
/// تعديل على كود الواجهة.
///
/// نستخدم حزمة الأيقونات المدمجة في Flutter (Icons.*) فقط — بدون إضافة
/// أي حزمة أيقونات خارجية جديدة للمشروع دون قرار صريح مسبق.
class MerchantCategoryIcon {
  const MerchantCategoryIcon._();

  static const IconData _fallback = Icons.storefront_rounded;

  /// أيقونات مطابِقة بدقة للإيموجي الأساسية المزروعة في قاعدة البيانات.
  static const Map<String, IconData> _byEmoji = {
    '🍔': Icons.restaurant_rounded,
    '🛒': Icons.local_grocery_store_rounded,
    '☕': Icons.local_cafe_rounded,
    '💄': Icons.face_retouching_natural_rounded,
    '👕': Icons.checkroom_rounded,
    '💊': Icons.local_pharmacy_rounded,
    '📱': Icons.devices_rounded,
    '🏠': Icons.chair_rounded,
    '🥖': Icons.bakery_dining_rounded,
    '🧴': Icons.auto_awesome_rounded,
    '🚬': Icons.storefront_rounded,
    '🔧': Icons.build_rounded,
    '🛍️': Icons.shopping_bag_rounded,
  };

  /// مطابقة احتياطية بالكلمات المفتاحية في الاسم — تغطي أي تصنيف تُضيفه
  /// الإدارة لاحقًا بإيموجي مختلف أو بدون إيموجي مطابَق أعلاه.
  static const Map<String, IconData> _byKeyword = {
    'مطعم': Icons.restaurant_rounded,
    'مطاعم': Icons.restaurant_rounded,
    'بقال': Icons.local_grocery_store_rounded,
    'غذائ': Icons.local_grocery_store_rounded,
    'مشروب': Icons.local_cafe_rounded,
    'مقه': Icons.local_cafe_rounded,
    'قهو': Icons.local_cafe_rounded,
    'جمال': Icons.face_retouching_natural_rounded,
    'عناي': Icons.face_retouching_natural_rounded,
    'ملابس': Icons.checkroom_rounded,
    'أزياء': Icons.checkroom_rounded,
    'ازياء': Icons.checkroom_rounded,
    'صح': Icons.local_pharmacy_rounded,
    'صيدل': Icons.local_pharmacy_rounded,
    'إلكترون': Icons.devices_rounded,
    'الكترون': Icons.devices_rounded,
    'منزل': Icons.chair_rounded,
    'بيت': Icons.chair_rounded,
    'مخبز': Icons.bakery_dining_rounded,
    'مخابز': Icons.bakery_dining_rounded,
    'حلويات': Icons.bakery_dining_rounded,
    'عطور': Icons.auto_awesome_rounded,
    'عطر': Icons.auto_awesome_rounded,
    'كشك': Icons.storefront_rounded,
    'أكشاك': Icons.storefront_rounded,
    'خدم': Icons.build_rounded,
    'حذاء': Icons.dry_cleaning_rounded,
    'أحذية': Icons.dry_cleaning_rounded,
  };

  /// لوحة ألوان احترافية هادئة — تُختار للتصنيف حسب هوية (id) ثابتة، حتى
  /// يحتفظ كل تصنيف بنفس لونه دائمًا ولا يتغيّر عشوائيًا بين الفتحات.
  static const List<Color> _palette = [
    Color(0xFFE0693F), // طوبي
    Color(0xFF2E8B84), // أخضر مزرق
    Color(0xFF6B5CA5), // بنفسجي
    Color(0xFFC9922E), // كهرماني
    Color(0xFF3D7DBF), // أزرق
    Color(0xFFB25B8E), // خوخي غامق
    Color(0xFF4F9153), // أخضر ورقي
    Color(0xFFC65656), // أحمر طوبي
    Color(0xFF5D7A9E), // أزرق رمادي
    Color(0xFFB68B3E), // بني ذهبي
  ];

  static IconData iconFor(MerchantCategory category) {
    final byEmoji = _byEmoji[category.icon];
    if (byEmoji != null) return byEmoji;

    final name = category.name;
    for (final entry in _byKeyword.entries) {
      if (name.contains(entry.key)) return entry.value;
    }

    return _fallback;
  }

  static Color colorFor(String categoryId) {
    final index = categoryId.hashCode.abs() % _palette.length;
    return _palette[index];
  }
}
