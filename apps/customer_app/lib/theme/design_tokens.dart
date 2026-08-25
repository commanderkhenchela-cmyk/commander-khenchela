import 'package:flutter/material.dart';

/// Design Tokens مركزية — Spacing وRadius وألوان دلالية (Muted/Border/
/// Success/Warning) موحَّدة، بدل قيم متفرّقة (8، 12، 14، 16...) مكتوبة
/// يدويًا في كل شاشة. Colors الأساسية (Primary/Background/Surface/Text/
/// Error) تبقى من [ColorScheme] عبر [AppTheme] كما هي — هذا الملف
/// *يكمّلها*، لا يستبدلها.
///
/// نطاق الاستخدام حاليًا: الشاشات الجديدة أو المُعاد تنظيمها في هذه
/// المرحلة (البحث، مكوّنات الرئيسية المُستخرَجة) — بقية الشاشات القديمة
/// تستمر بقيمها المباشرة كما هي، تُهاجَر تدريجيًا لاحقًا بلا مخاطرة على
/// الشاشات المستقرة (نفس مبدأ "Refactor تدريجي وآمن" المتّفق عليه).
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double card = 16;
  static const double lg = 18;
  static const double pill = 20;
  static const double xl = 24;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// ألوان دلالية لا يوفّرها [ColorScheme] القياسي مباشرة (Success/Warning/
/// Muted/Border) — محسوبة من نفس [ColorScheme] الحالي (يحترم الوضع
/// الداكن/الفاتح والهوية الديناميكية من BrandingService تلقائيًا)، لا
/// قيم Hex جديدة منفصلة عنه.
extension AppColorsX on ColorScheme {
  Color get success => brightness == Brightness.dark
      ? const Color(0xFF4CAF6D)
      : const Color(0xFF1B7A3D);

  Color get warning => brightness == Brightness.dark
      ? const Color(0xFFE0A94A)
      : const Color(0xFFB26A00);

  Color get muted => onSurface.withValues(alpha: 0.6);
  Color get border => onSurface.withValues(alpha: 0.12);
}
