import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_request_job.dart';

/// كل تعاملات جدول delivery_requests ("اطلب أي شيء") من منظور الموصّل —
/// نفس فلسفة OrderService بالحرف (RLS تحدّد الصفوف، هذه فقط تفلتر بين
/// المجمع المتاح وطلباتي).
///
/// فرق جوهري عن OrderService: لا نستعلم عنوان التسليم إطلاقًا فـ
/// fetchAvailable — RLS (addresses_select_driver_via_delivery_requests)
/// تمنعه أصلًا قبل القبول (driver_id لم يُعيَّن بعد)، فطلب العمود هنا لن
/// يُرجع أي شيء مفيد. العنوان يُجلَب فقط عبر fetchDetail، وتلك تُستدعى
/// فقط لطلب مقبول فعليًا (راجع تعليق home screen لسبب فصل الشاشتين).
class DeliveryRequestService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _baseColumns =
      'id, description, status, delivery_fee, driver_earning_share, created_at, accepted_at';
  static const _detailColumns =
      '$_baseColumns, addresses(address_text, phone, communes(name))';

  /// طلبات pending وبلا موصّل بعد — أي موصّل موافَق عليه يقدر يقبلها.
  static Future<List<DeliveryRequestJob>> fetchAvailable() async {
    final rows = await _client
        .from('delivery_requests')
        .select(_baseColumns)
        .eq('status', 'pending')
        .isFilter('driver_id', null)
        .order('created_at');

    return (rows as List)
        .map((row) => DeliveryRequestJob.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// الطلبات التي قبِلها هذا الموصّل ولم تُسلَّم بعد. delivered وcancelled
  /// معًا مستبعدان (بخلاف orders حيث cancelled بعد التعيين مستحيلة
  /// أصلًا) — الإدارة تقدر تُلغي طلب delivery_request مقبولًا فعليًا
  /// (راجع validate_delivery_request_status_transition)، فبلا استبعاد
  /// cancelled هنا كانت تبقى عالقة للأبد فـ "طلباتي".
  static Future<List<DeliveryRequestJob>> fetchMine() async {
    final rows = await _client
        .from('delivery_requests')
        .select(_detailColumns)
        .not('driver_id', 'is', null)
        .not('status', 'in', '(delivered,cancelled)')
        .order('created_at');

    return (rows as List)
        .map((row) => DeliveryRequestJob.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// تفاصيل طلب واحد — تُستدعى فقط لطلب مقبول (أو مسلَّم/ملغى) فعليًا،
  /// أبدًا لطلب pending فـ المجمع (راجع تعليق الكلاس أعلاه).
  static Future<DeliveryRequestJob> fetchDetail(String requestId) async {
    final row = await _client
        .from('delivery_requests')
        .select(_detailColumns)
        .eq('id', requestId)
        .single();
    return DeliveryRequestJob.fromMap(row);
  }

  static Future<void> accept(String requestId) async {
    await _client.rpc(
      'driver_accept_delivery_request',
      params: {'p_request_id': requestId},
    );
  }

  static Future<void> complete(String requestId) async {
    await _client.rpc(
      'driver_complete_delivery_request',
      params: {'p_request_id': requestId},
    );
  }
}
