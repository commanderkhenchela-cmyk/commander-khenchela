/// حركة واحدة فـ محفظة الموصّل — راجع migration
/// 20260918000000_driver_wallet. RLS (driver_wallet_transactions_select_
/// own_driver) تحصر النتيجة على صاحب الجلسة تلقائيًا، لا حاجة لتمرير
/// driver_id يدويًا فـ أي استعلام.
class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String? note;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.note,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'topup':
        return 'إيداع (دفعة مكتب)';
      case 'deduction':
        return 'خصم يدوي';
      case 'commission':
        return 'عمولة مهمّة';
      default:
        return type;
    }
  }
}
