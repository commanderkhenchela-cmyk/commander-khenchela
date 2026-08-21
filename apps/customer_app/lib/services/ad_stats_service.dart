import 'package:supabase_flutter/supabase_flutter.dart';

/// يسجّل إحصائيات الإعلانات عبر دالة RPC واحدة محكومة (increment_ad_stat)
/// — لا تحديث مباشر على جدول advertisements من العميل أبدًا (راجع
/// تعليق الأمان في migration الإعلانات). بنفس فلسفة باقي الخدمات في
/// هذا المشروع: لا يرمي أي استثناء أبدًا — فشل تسجيل إحصائية لا يجب
/// أن يوقف تشغيل الفيديو أو يزعج المستخدم بأي شكل.
class AdStatsService {
  const AdStatsService._();

  static Future<void> _increment(String adId, String stat) async {
    try {
      await Supabase.instance.client.rpc(
        'increment_ad_stat',
        params: {'p_ad_id': adId, 'p_stat': stat},
      );
    } catch (_) {
      // تجاهل صامت — إحصائية واحدة غير مسجَّلة لا تستحق إزعاج المستخدم.
    }
  }

  static Future<void> recordView(String adId) => _increment(adId, 'view');

  static Future<void> recordVideoStart(String adId) =>
      _increment(adId, 'video_start');

  static Future<void> recordVideoCompletion(String adId) =>
      _increment(adId, 'video_completion');

  static Future<void> recordClick(String adId) => _increment(adId, 'click');
}
