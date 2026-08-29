import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver.dart';

/// يُرمى عند نجاح إنشاء صفّ drivers لكن فشل رفع بطاقة التعريف بعده —
/// حالة شبكة عابرة نادرة نريد تمييزها عن فشل الإرسال الكامل، لأن صفّ
/// الموصّل بات موجودًا فعليًا بحلول هذه اللحظة (راجع onboarding_screen).
class IdCardUploadException implements Exception {
  const IdCardUploadException();
}

/// كل تعاملات جدول drivers الخاصة بحساب الموصّل الحالي — RLS
/// (drivers_select_own/drivers_update_own) تحصر كل عملية هنا على صفّه
/// هو فقط، فلا حاجة لتمرير user_id يدويًا في أي استعلام.
class DriverService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// null يعني: لا يوجد صفّ drivers بعد لهذا الحساب (لم يُكمل onboarding).
  static Future<Driver?> fetchOwnDriver() async {
    final row = await _client
        .from('drivers')
        .select('id, full_name, phone, vehicle_type, status, is_online')
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();

    if (row == null) return null;
    return Driver.fromMap(row);
  }

  /// ينشئ صفّ الموصّل ثم يرفع بطاقة تعريفه إلى bucket خاص
  /// (driver-documents) تحت مجلد باسم معرّف الصفّ الجديد نفسه — نفس
  /// نمط صور المحل (merchant-images) لكن bucket خاص لا عام، لأن بطاقة
  /// التعريف بيانات حسّاسة. لا تفعيل قبل مراجعة الإدارة للوثيقة (نفس
  /// شرط المتطلَّبات الأصلي).
  static Future<void> submitOnboarding({
    required String fullName,
    required String phone,
    required File idCardImage,
  }) async {
    final inserted = await _client
        .from('drivers')
        .insert({
          'user_id': _client.auth.currentUser!.id,
          'full_name': fullName,
          'phone': phone,
          // status/vehicle_type يُتركان لقيمهما الافتراضية (pending/bike) —
          // نفس نمط merchants_insert_own، RLS تفرض status = 'pending' على
          // أي حال حتى لو أرسل العميل قيمة مختلفة.
        })
        .select('id')
        .single();

    final driverId = inserted['id'] as String;

    try {
      final ext = idCardImage.path.split('.').last.toLowerCase();
      final path = '$driverId/id_card.$ext';
      await _client.storage
          .from('driver-documents')
          .upload(path, idCardImage, fileOptions: const FileOptions(upsert: true));
      await _client.from('drivers').update({'id_card_path': path}).eq('id', driverId);
    } catch (_) {
      // صفّ drivers أُنشئ فعلًا فـ هذه اللحظة — لا نتراجع عنه (لا حذف
      // ذاتي هنا)، فقط نُعلم الواجهة أن الوثيقة لم تُرفَع لتعرض رسالة
      // مختلفة عن فشل الإرسال الكامل.
      throw const IdCardUploadException();
    }
  }

  static Future<void> setOnline(bool value) async {
    await _client
        .from('drivers')
        .update({'is_online': value})
        .eq('user_id', _client.auth.currentUser!.id);
  }

  static Future<void> pingLocation({
    required double lat,
    required double lng,
  }) async {
    await _client
        .from('drivers')
        .update({
          'current_lat': lat,
          'current_lng': lng,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _client.auth.currentUser!.id);
  }
}
