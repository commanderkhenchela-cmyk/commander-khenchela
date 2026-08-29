/// طلبية كما يراها الموصّل — في "الطلبات المتاحة" و"طلباتي" (قائمة
/// خفيفة، معلومات المحل فقط). راجع RLS orders_select_driver_pool/
/// orders_select_driver_own في migration 20260822010000_drivers.sql.
class JobOrder {
  final String id;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double driverEarningShare;
  final double totalAmount;
  final String paymentStatus;
  final DateTime createdAt;
  final String merchantName;
  final String? merchantPhone;
  final String? merchantAddressText;
  final double? merchantLat;
  final double? merchantLng;

  const JobOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.driverEarningShare,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdAt,
    required this.merchantName,
    required this.merchantPhone,
    required this.merchantAddressText,
    required this.merchantLat,
    required this.merchantLng,
  });

  factory JobOrder.fromMap(Map<String, dynamic> map) {
    // merchants قد تُرجَع null من RLS في حالات نادرة (راجع migration
    // 20260823030000) — لا نكسر شاشة "الطلبات المتاحة" كاملة لأجل اسم
    // محل واحد غير متاح، نعرض بديلًا محايدًا بدلًا من ذلك.
    final merchant = map['merchants'] as Map<String, dynamic>?;
    return JobOrder(
      id: map['id'] as String,
      status: map['status'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      deliveryFee: (map['delivery_fee'] as num).toDouble(),
      driverEarningShare: (map['driver_earning_share'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentStatus: map['payment_status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      merchantName: merchant?['store_name'] as String? ?? 'محل غير معروف',
      merchantPhone: merchant?['phone'] as String?,
      merchantAddressText: merchant?['address_text'] as String?,
      merchantLat: (merchant?['latitude'] as num?)?.toDouble(),
      merchantLng: (merchant?['longitude'] as num?)?.toDouble(),
    );
  }

  /// تسمية عربية واضحة للحالة — من منظور الموصّل تحديدًا (الحالات التي
  /// تسبق ready_for_pickup لا تظهر له إطلاقًا بسبب RLS، فلا داعي لها هنا).
  static String statusLabel(String status) {
    switch (status) {
      case 'ready_for_pickup':
        return 'جاهز للاستلام';
      case 'picked_up':
        return 'تم الاستلام من المحل';
      case 'out_for_delivery':
        return 'في الطريق للعميل';
      case 'delivered':
        return 'تم التسليم ✅';
      default:
        return status;
    }
  }
}

class JobItem {
  final String productName;
  final int quantity;

  const JobItem({required this.productName, required this.quantity});

  factory JobItem.fromMap(Map<String, dynamic> map) {
    return JobItem(
      productName: (map['products'] as Map<String, dynamic>)['name'] as String,
      quantity: map['quantity'] as int,
    );
  }
}

/// تفاصيل طلبية واحدة كاملة — يُجلب فقط عند فتح شاشة التفاصيل (يحتاج
/// RLS addresses_select_driver_via_orders لرؤية عنوان/هاتف العميل).
class JobDetail {
  final JobOrder order;
  final String customerAddressText;
  final String? customerPhone;
  final String communeName;
  final List<JobItem> items;

  const JobDetail({
    required this.order,
    required this.customerAddressText,
    required this.customerPhone,
    required this.communeName,
    required this.items,
  });

  factory JobDetail.fromMap(Map<String, dynamic> map) {
    final address = map['addresses'] as Map<String, dynamic>;
    final commune = address['communes'] as Map<String, dynamic>;
    final itemRows = map['order_items'] as List;

    return JobDetail(
      order: JobOrder.fromMap(map),
      customerAddressText: address['address_text'] as String,
      customerPhone: address['phone'] as String?,
      communeName: commune['name'] as String,
      items: itemRows
          .map((row) => JobItem.fromMap(row as Map<String, dynamic>))
          .toList(),
    );
  }
}
