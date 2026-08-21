import 'package:supabase_flutter/supabase_flutter.dart';

/// يسجّل مشاهدة صفحة محل عبر دالة RPC واحدة محكومة
/// (increment_merchant_view) — لا تحديث مباشر على جدول merchants من
/// العميل أبدًا (راجع تعليق الأمان في migration المشاهدات). بنفس
/// فلسفة AdStatsService: لا يرمي أي استثناء أبدًا — فشل تسجيل مشاهدة
/// واحدة لا يجب أن يزعج المستخدم أو يعطّل فتح صفحة المحل بأي شكل.
class MerchantViewsService {
  const MerchantViewsService._();

  static Future<void> recordView(String merchantId) async {
    try {
      await Supabase.instance.client.rpc(
        'increment_merchant_view',
        params: {'p_merchant_id': merchantId},
      );
    } catch (_) {
      // تجاهل صامت — نفس منطق AdStatsService.
    }
  }
}
