import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_transaction.dart';

/// كل تعاملات جدول driver_wallet_transactions — للقراءة فقط (لا زر
/// إيداع/خصم فـ التطبيق، هذا حصريًا من طرف الإدارة عبر
/// admin_driver_wallet_topup/admin_driver_wallet_deduct). RLS
/// (driver_wallet_transactions_select_own_driver) تحصر النتيجة على صفّ
/// الموصّل الحالي تلقائيًا، نفس فلسفة DriverService بالحرف.
class WalletService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<WalletTransaction>> fetchTransactions() async {
    final rows = await _client
        .from('driver_wallet_transactions')
        .select('id, type, amount, note, created_at')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => WalletTransaction.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
