import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = 'recent_searches';
const int _maxItems = 10;

/// عمليات البحث الأخيرة — محلية بالكامل (SharedPreferences)، بغضّ
/// النظر عن حالة تسجيل الدخول (نفس فلسفة CartService: لا نجبر أحدًا
/// على تسجيل الدخول لميزة لا تحتاجه فعليًا). الأحدث دائمًا أولًا،
/// وبلا تكرار (نفس النص يُنقَل لأعلى القائمة بدل تكراره).
class RecentSearchesService {
  const RecentSearchesService._();

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefsKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_prefsKey) ?? [];
      final updated = [
        trimmed,
        ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
      ].take(_maxItems).toList();
      await prefs.setStringList(_prefsKey, updated);
      return updated;
    } catch (_) {
      return load();
    }
  }

  static Future<List<String>> remove(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_prefsKey) ?? [];
      final updated = current.where((q) => q != query).toList();
      await prefs.setStringList(_prefsKey, updated);
      return updated;
    } catch (_) {
      return load();
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // فشل الحذف نادر جدًا هنا — لا داعي لأي معالجة إضافية.
    }
  }
}
