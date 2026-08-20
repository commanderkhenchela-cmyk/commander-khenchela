import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// هوية التطبيق (الاسم، الشعار، الألوان) — تُقرأ من جدول app_branding
/// (قراءة عامة، تعديل من لوحة الإدارة فقط) عند بدء التشغيل، قبل بناء
/// أول واجهة، حتى لا تظهر الألوان الافتراضية للحظة ثم "تقفز" لاحقًا.
///
/// إن فشل التحميل (لا إنترنت، مهلة انتهت...) يبقى التطبيق يعمل بالكامل
/// بالقيم الافتراضية الثابتة أدناه — لا يتوقف التطبيق أبدًا بسبب هذا.
class BrandingService {
  BrandingService._();

  static const _defaultAppName = 'كوموندور خنشلة';
  static const _defaultPrimary = Color(0xFF1B7A3D);
  static const _defaultError = Color(0xFFB3261E);

  static String appName = _defaultAppName;
  static String? logoUrl;
  static Color primaryColor = _defaultPrimary;
  static Color errorColor = _defaultError;

  static Future<void> load() async {
    try {
      final data = await Supabase.instance.client
          .from('app_branding')
          .select('app_name, logo_url, primary_color, error_color')
          .eq('id', 'default')
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (data == null) return;

      appName = data['app_name'] as String? ?? _defaultAppName;
      logoUrl = data['logo_url'] as String?;
      primaryColor =
          _parseHexColor(data['primary_color'] as String?) ?? _defaultPrimary;
      errorColor =
          _parseHexColor(data['error_color'] as String?) ?? _defaultError;
    } catch (_) {
      // تجاهل بصمت: القيم الافتراضية أعلاه كافية لتشغيل التطبيق بشكل طبيعي.
    }
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value == null ? null : Color(value);
  }
}
