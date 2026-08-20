/// إعدادات الاتصال بـ Supabase.
///
/// ملاحظة أمان مهمة: "publishableKey" هنا هو مفتاح عام (يُسمى أيضًا anon key
/// في بعض النسخ) وليس سرًا — Supabase صمّمه ليكون آمنًا للتضمين داخل تطبيق
/// العميل (Flutter/Web)، والحماية الحقيقية تأتي من قواعد RLS في قاعدة
/// البيانات (راجع PHASE 3).
///
/// أما "Service Role Key" أو "Secret Key" (لم نستخدمه هنا إطلاقًا) فهو
/// المفتاح السرّي الذي يجب ألا يظهر أبدًا داخل أي تطبيق (Flutter/Web/Browser).
class SupabaseConfig {
  /// رابط مشروع Supabase (من Settings → API → Project URL)
  static const String url = 'https://dwmllbtvhzilwrmyurom.supabase.co';

  /// المفتاح العام (من Settings → API → Project API keys —
  /// قد يظهر باسم "publishable key" أو "anon public" حسب نسخة اللوحة)
  /// ضع القيمة الحقيقية هنا بدل النص أدناه.
  static const String publishableKey =
      'sb_publishable_H9fV2tkBj8dSTA2U0oqvYw_rz2VbKtv';
}
