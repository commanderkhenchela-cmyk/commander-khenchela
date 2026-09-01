import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride_job.dart';

/// كل تعاملات جدول ride_requests من منظور الموصّل — نفس فلسفة
/// OrderService/DeliveryRequestService. بخلاف DeliveryRequestService،
/// عنوانا الانطلاق/الوجهة مرئيان حتى فـ fetchAvailable (RLS
/// addresses_select_driver_via_ride_pool تسمح بذلك صراحة)، فلا حاجة
/// لفصل شاشتَي المجمّع والتفاصيل كما فعلنا هناك.
class RideRequestService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _columns =
      'id, status, fare, driver_earning_share, created_at, '
      'pickup_address:addresses!pickup_address_id(address_text, phone, communes(name)), '
      'dropoff_address:addresses!dropoff_address_id(address_text, phone, communes(name))';

  static Future<List<RideJob>> fetchAvailable() async {
    final rows = await _client
        .from('ride_requests')
        .select(_columns)
        .eq('status', 'pending')
        .isFilter('driver_id', null)
        .order('created_at');

    return (rows as List)
        .map((row) => RideJob.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<List<RideJob>> fetchMine() async {
    final rows = await _client
        .from('ride_requests')
        .select(_columns)
        .not('driver_id', 'is', null)
        .not('status', 'in', '(completed,cancelled)')
        .order('created_at');

    return (rows as List)
        .map((row) => RideJob.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<RideJob> fetchDetail(String requestId) async {
    final row = await _client
        .from('ride_requests')
        .select(_columns)
        .eq('id', requestId)
        .single();
    return RideJob.fromMap(row);
  }

  static Future<void> accept(String requestId) async {
    await _client.rpc(
      'driver_accept_ride_request',
      params: {'p_request_id': requestId},
    );
  }

  static Future<void> release(String requestId) async {
    await _client.rpc(
      'driver_release_ride_request',
      params: {'p_request_id': requestId},
    );
  }

  static Future<void> start(String requestId) async {
    await _client.rpc('driver_start_ride', params: {'p_request_id': requestId});
  }

  static Future<void> complete(String requestId) async {
    await _client.rpc(
      'driver_complete_ride',
      params: {'p_request_id': requestId},
    );
  }
}
