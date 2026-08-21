import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsThemeModeKey = 'theme_mode';

/// يتحكّم بوضع الثيم الحالي (فاتح/داكن/تلقائي حسب النظام) عبر كل
/// التطبيق، ويحفظ اختيار المستخدم محليًا حتى يبقى بعد إغلاق التطبيق.
/// [ThemeMode.system] هو الافتراضي — يتبع إعداد الجهاز نفسه تلقائيًا،
/// وهذا وضع "داكن حقيقي" فعليًا (ColorScheme.fromSeed بـ brightness:
/// dark في AppTheme.dark) وليس مجرَّد عكس ألوان الوضع الفاتح.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsThemeModeKey);
      _mode = _fromString(saved) ?? ThemeMode.system;
      notifyListeners();
    } catch (_) {
      // فشل القراءة (نادر) → يبقى الوضع التلقائي (system)، لا يتوقّف
      // التطبيق أبدًا بسبب هذا (نفس فلسفة BrandingService/ContactService).
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsThemeModeKey, _toString(mode));
    } catch (_) {
      // فشل الحفظ لا يمنع تطبيق الاختيار في الجلسة الحالية، فقط لن يُحفظ
      // للمرة القادمة.
    }
  }

  static ThemeMode? _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
