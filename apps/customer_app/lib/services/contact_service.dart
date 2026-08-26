import 'package:supabase_flutter/supabase_flutter.dart';

/// بيانات التواصل (واتساب/هاتف/بريد/شبكات اجتماعية) — تُقرأ من جدول
/// app_contact (تُعدَّل من لوحة الإدارة). نفس نمط BrandingService بالضبط:
/// تحميل مرة واحدة عند بدء التشغيل، وفشل التحميل لا يوقف التطبيق أبدًا.
class ContactService {
  ContactService._();

  static String whatsappNumber = '213770773844';
  static String displayPhone = '0770 77 38 44';
  static String supportEmail = 'support@commanderkhenchela.dz';
  static String? facebookUrl;
  static String? instagramUrl;

  static Future<void> load() async {
    try {
      final data = await Supabase.instance.client
          .from('app_contact')
          .select(
            'whatsapp_number, display_phone, support_email, facebook_url, instagram_url',
          )
          .eq('id', 'default')
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (data == null) return;

      whatsappNumber = data['whatsapp_number'] as String? ?? whatsappNumber;
      displayPhone = data['display_phone'] as String? ?? displayPhone;
      supportEmail = data['support_email'] as String? ?? supportEmail;
      facebookUrl = data['facebook_url'] as String?;
      instagramUrl = data['instagram_url'] as String?;
    } catch (_) {
      // تجاهل بصمت — القيم الافتراضية أعلاه كافية.
    }
  }
}
