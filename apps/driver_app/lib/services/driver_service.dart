import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver.dart';

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

  static Future<void> submitOnboarding({
    required String fullName,
    required String phone,
  }) async {
    await _client.from('drivers').insert({
      'user_id': _client.auth.currentUser!.id,
      'full_name': fullName,
      'phone': phone,
      // status/vehicle_type يُتركان لقيمهما الافتراضية (pending/bike) —
      // نفس نمط merchants_insert_own، RLS تفرض status = 'pending' على
      // أي حال حتى لو أرسل العميل قيمة مختلفة.
    });
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
