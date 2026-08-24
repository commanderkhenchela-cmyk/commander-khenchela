import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsLocaleKey = 'locale_code';

/// يتحكّم بلغة الواجهة الحالية، ويحفظ اختيار المستخدم محليًا — نفس نمط
/// ThemeController بالضبط. العربية هي الافتراضي وتبقى اللغة الوحيدة
/// المكتملة الترجمة حاليًا (راجع lib/l10n/*.arb)؛ الفرنسية والإنجليزية
/// مفعَّلتان معماريًا (AppLocalizations تدعمهما فعليًا) لكن عدد قليل من
/// النصوص منقول إليهما حتى الآن — بقية الشاشات لا تزال عربية Hardcoded
/// بغضّ النظر عن هذا الاختيار، إلى أن تُنقَل تباعًا.
class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsLocaleKey);
      if (saved != null) _locale = Locale(saved);
      notifyListeners();
    } catch (_) {
      // فشل القراءة (نادر) → تبقى العربية، لا يتوقّف التطبيق أبدًا لهذا.
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLocaleKey, locale.languageCode);
    } catch (_) {
      // فشل الحفظ لا يمنع تطبيق الاختيار في الجلسة الحالية.
    }
  }
}
