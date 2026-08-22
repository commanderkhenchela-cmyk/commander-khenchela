import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة تسجيل الدخول: رقم الهاتف + كلمة سر — نفس تقنية تطبيق الزبون
/// حرفيًا (Supabase لا يدعم تسجيل بدون بريد، فنولّد بريدًا مموّهًا من
/// رقم الهاتف تلقائيًا، الموصّل لا يرى أو يكتب أي بريد إطلاقًا).
///
/// قيد معروف: رقم هاتف مسجَّل مسبقًا كعميل أو تاجر (في نفس مشروع
/// Supabase) لا يقدر يسجّل حسابًا جديدًا كموصّل بنفس الرقم — تعارض على
/// مستوى auth.users نفسه (البريد المموَّه من نفس الرقم يصير مستخدَمًا
/// بالفعل). غير محلول في هذه المرحلة، ويظهر كخطأ "مسجَّل بالفعل" عاديّ.
class AuthService {
  static const String _emailDomain = '@phone.commanderkhenchela.local';

  static final SupabaseClient _client = Supabase.instance.client;

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
      data: {'phone': phone, 'full_name': fullName, 'role': 'driver'},
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
