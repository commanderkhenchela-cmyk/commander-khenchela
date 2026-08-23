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

  /// تسمية عربية واضحة لكل حالة، مطابقة لدورة حياة الطلب في PHASE 1.
  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة من المحل';
      case 'confirmed':
        return 'تم قبول الطلب';
      case 'preparing':
        return 'قيد التجهيز';
      case 'ready_for_pickup':
        return 'جاهز للاستلام';
      case 'picked_up':
        return 'مع الموصّل';
      case 'out_for_delivery':
        return 'في الطريق إليك';
      case 'delivered':
        return 'تم التوصيل ✅';
      case 'cancelled':
        return 'أُلغي الطلب';
      case 'rejected':
        return 'رفض المحل الطلب';
      default:
        return status;
    }
  }
}
