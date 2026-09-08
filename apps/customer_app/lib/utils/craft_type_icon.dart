import 'package:flutter/material.dart';

/// أيقونة Material لكل تصنيف حرفة — نفس فلسفة ServiceIcon (service_icon.dart):
/// تطابق بـslug ثابت (craft_type)، لا بالاسم المترجَم، لأن القائمة مغلقة
/// ومعروفة سلفًا (نفس قيد check فـ migration 20260907000000).
class CraftTypeIcon {
  const CraftTypeIcon._();

  static const IconData _fallback = Icons.handyman_outlined;

  static const Map<String, IconData> _bySlug = {
    'plumber': Icons.plumbing_outlined,
    'electrician': Icons.electrical_services_outlined,
    'painter': Icons.format_paint_outlined,
    'carpenter': Icons.carpenter_outlined,
    'locksmith': Icons.key_outlined,
    'ac_technician': Icons.ac_unit_outlined,
    'general': Icons.build_outlined,
  };

  static IconData iconFor(String craftType) => _bySlug[craftType] ?? _fallback;
}
