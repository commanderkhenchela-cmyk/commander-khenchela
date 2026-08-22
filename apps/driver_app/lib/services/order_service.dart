import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/job_order.dart';

/// كل تعاملات جدول orders (ومحيطه) من منظور الموصّل. RLS
/// (orders_select_driver_pool/orders_select_driver_own في migration
/// 20260822010000_drivers.sql) تحدّد فعليًا أي الصفوف تظهر أصلًا — هذه
/// الاستعلامات تُضيف فلاتر عميل واضحة فوقها فقط للتمييز بين "المجمع
/// المتاح" (driver_id فارغ) و"طلباتي" (driver_id مُعيَّن)، لأن سياستَي
/// RLS تُدمَجان بـ OR على أي SELECT بدون فلتر.
class OrderService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _jobColumns =
      'id, status, subtotal, delivery_fee, total_amount, payment_status, '
      'created_at, merchants(store_name, phone, address_text, latitude, longitude)';

  /// طلبات جاهزة للاستلام ولم يُعيَّن لها موصّل بعد — أي موصّل موافَق
  /// عليه يقدر يستلمها (driver_claim_order).
  static Future<List<JobOrder>> fetchAvailableJobs() async {
    final rows = await _client
        .from('orders')
        .select(_jobColumns)
        .eq('status', 'ready_for_pickup')
        .isFilter('driver_id', null)
        .order('created_at');

    return (rows as List)
        .map((row) => JobOrder.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// الطلبات التي استلمها هذا الموصّل فعليًا ولم تُسلَّم بعد.
  static Future<List<JobOrder>> fetchMyJobs() async {
    final rows = await _client
        .from('orders')
        .select(_jobColumns)
        .not('driver_id', 'is', null)
        .neq('status', 'delivered')
        .order('created_at');

    return (rows as List)
        .map((row) => JobOrder.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<JobDetail> fetchJobDetail(String orderId) async {
    final row = await _client
        .from('orders')
        .select(
          '$_jobColumns, '
          'addresses(address_text, phone, communes(name)), '
          'order_items(quantity, products(name))',
        )
        .eq('id', orderId)
        .single();

    return JobDetail.fromMap(row);
  }

  static Future<void> claimJob(String orderId) async {
    await _client.rpc('driver_claim_order', params: {'p_order_id': orderId});
  }

  static Future<void> releaseJob(String orderId) async {
    await _client.rpc('driver_release_order', params: {'p_order_id': orderId});
  }

  /// تقدّم بالحالة التالية — RLS (orders_update_driver) + trigger
  /// (validate_order_status_transition) هما من يقرران شرعية الانتقال
  /// فعليًا، نفس نمط order-actions.tsx في لوحة الإدارة تمامًا.
  static Future<void> advanceStatus(String orderId, String toStatus) async {
    await _client.from('orders').update({'status': toStatus}).eq('id', orderId);
  }
}
