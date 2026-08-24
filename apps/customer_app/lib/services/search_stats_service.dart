import 'package:supabase_flutter/supabase_flutter.dart';

/// يسجّل نص بحث لبناء قائمة "عمليات بحث شائعة" حقيقية — نفس نمط
/// MerchantViewsService بالضبط (دالة RPC واحدة محكومة، لا تحديث مباشر
/// من العميل، لا يرمي استثناء أبدًا).
class SearchStatsService {
  const SearchStatsService._();

  static Future<void> record(String query) async {
    try {
      await Supabase.instance.client.rpc(
        'record_search_query',
        params: {'p_query': query},
      );
    } catch (_) {
      // تجاهل صامت — نفس منطق MerchantViewsService/AdStatsService.
    }
  }

  /// أعلى N نصوص بحث تكرارًا — تُستخدم فقط عند شاشة البحث فارغة (قبل
  /// أن يكتب المستخدم أي شيء).
  static Future<List<String>> fetchPopular({int limit = 8}) async {
    final data = await Supabase.instance.client
        .from('search_queries')
        .select('query')
        .order('search_count', ascending: false)
        .limit(limit);

    return (data as List).map((row) => row['query'] as String).toList();
  }
}
