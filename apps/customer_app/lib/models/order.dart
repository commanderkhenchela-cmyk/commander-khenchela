import '../l10n/app_localizations.dart';

/// نموذج طلبية، مطابق لجدول orders (+ اسم المحل من علاقة merchants).
class CustomerOrder {
  final String id;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final DateTime createdAt;
  final String merchantName;

  const CustomerOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.createdAt,
    required this.merchantName,
  });

  factory CustomerOrder.fromMap(Map<String, dynamic> map) {
    // merchants قد تُرجَع null من RLS في حالات نادرة (راجع migration
    // 20260823030000) — لا نكسر الشاشة كاملة لأجل اسم محل واحد غير
    // متاح، نعرض بديلًا محايدًا بدلًا من ذلك.
    final merchant = map['merchants'] as Map<String, dynamic>?;
    return CustomerOrder(
      id: map['id'] as String,
      status: map['status'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      deliveryFee: (map['delivery_fee'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      merchantName: merchant?['store_name'] as String? ?? 'محل غير معروف',
    );
  }

  /// تسمية مترجَمة واضحة لكل حالة، مطابقة لدورة حياة الطلب في PHASE 1.
  /// تأخذ [AppLocalizations] بدل الاعتماد على BuildContext مباشرة — يبقي
  /// الموديل بلا اعتماد مباشر على شجرة الـWidgets، والمستدعي (الشاشة)
  /// يمرّر AppLocalizations.of(context) كالمعتاد.
  static String statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.orderStatusPending;
      case 'confirmed':
        return l10n.orderStatusConfirmed;
      case 'preparing':
        return l10n.orderStatusPreparing;
      case 'ready_for_pickup':
        return l10n.orderStatusReadyForPickup;
      case 'picked_up':
        return l10n.orderStatusPickedUp;
      case 'out_for_delivery':
        return l10n.orderStatusOutForDelivery;
      case 'delivered':
        return l10n.orderStatusDelivered;
      case 'cancelled':
        return l10n.orderStatusCancelled;
      case 'rejected':
        return l10n.orderStatusRejected;
      default:
        return status;
    }
  }
}
