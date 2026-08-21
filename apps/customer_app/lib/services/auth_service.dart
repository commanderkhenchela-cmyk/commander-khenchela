import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة تسجيل الدخول: رقم الهاتف + كلمة سر (بدون SMS في V1).
///
/// تقنيًا نستخدم نظام Email/Password الأصلي في Supabase، لكن نولّد بريدًا
/// مموّهًا من رقم الهاتف تلقائيًا — العميل لا يرى أو يكتب أي بريد إطلاقًا.
/// راجع docs/phase5-auth-decision-and-test.md لتفاصيل هذا القرار.
class AuthService {
  static const String _emailDomain = '@phone.commanderkhenchela.local';

  static final SupabaseClient _client = Supabase.instance.client;

  /// يحوّل رقم الهاتف إلى بريد مموّه ثابت لنفس الرقم دائمًا.
  ///
  /// إصلاح خلل حقيقي: نموذج إنشاء الحساب وشاشة العنوان يقبلان كلا
  /// الصيغتين "0555xxxxxx" و"+213555xxxxxx" كرقم صحيح (نفس الرقم
  /// فعليًا)، لكن بدون التطبيع أدناه كانتا تُنتجان بريدَين مموَّهَين
  /// مختلفَين تمامًا لنفس الرقم — فلو سجّل عميل حسابه بصيغة وحاول
  /// الدخول لاحقًا بالصيغة الأخرى، يفشل الدخول بـ"بيانات غير صحيحة"
  /// رغم صحة كل شيء. الآن تُحوَّل صيغة +213 دائمًا لصيغتها المحلية
  /// (0xxxxxxxxx) أولًا، فتتطابق الصيغتان دومًا على نفس البريد المموَّه.
  static String phoneToEmail(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('213') && digits.length == 12) {
      digits = '0${digits.substring(3)}';
    }
    return '$digits$_emailDomain';
  }

  static User? get currentUser => _client.auth.currentUser;
  static bool get isSignedIn => currentUser != null;

  static Future<void> signUp({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    await _client.auth.signUp(
      email: phoneToEmail(phone),
      password: password,
      data: {'phone': phone, 'full_name': fullName, 'role': 'customer'},
    );
  }

  static Future<void> signIn({
    required String phone,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: phoneToEmail(phone),
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
