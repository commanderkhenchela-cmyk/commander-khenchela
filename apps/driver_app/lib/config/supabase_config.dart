/// إعدادات الاتصال بـ Supabase — نفس مشروع تطبيق الزبون ولوحتي
/// التاجر/الإدارة (Backend واحد لكل المشروع).
///
/// ملاحظة أمان: "publishableKey" مفتاح عام (anon key) وليس سرًا — آمن
/// للتضمين داخل تطبيق الزبون، والحماية الحقيقية تأتي من RLS في قاعدة
/// البيانات (راجع migration 20260822010000_drivers.sql).
class SupabaseConfig {
  static const String url = 'https://dwmllbtvhzilwrmyurom.supabase.co';

  static const String publishableKey =
      'sb_publishable_H9fV2tkBj8dSTA2U0oqvYw_rz2VbKtv';
}
