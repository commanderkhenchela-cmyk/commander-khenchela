/// طلب "اطلب أي شيء" كما يراه الموصّل — راجع migration
/// 20260905000000_delivery_requests. بخلاف JobOrder، لا "محل استلام"
/// هنا إطلاقًا — فقط وصف نصي كتبه العميل، وعنوان تسليم واحد يظهر فقط
/// بعد القبول فعليًا (RLS addresses_select_driver_via_delivery_requests
/// تمنع رؤيته قبل ذلك عمدًا — راجع تعليق DeliveryRequestService).
class DeliveryRequestJob {
  final String id;
  final String description;
  final String status;
  final double deliveryFee;
  final double driverEarningShare;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? addressText;
  final String? communeName;
  final String? customerPhone;

  const DeliveryRequestJob({
    required this.id,
    required this.description,
    required this.status,
    required this.deliveryFee,
    required this.driverEarningShare,
    required this.createdAt,
    this.acceptedAt,
    this.addressText,
    this.communeName,
    this.customerPhone,
  });

  factory DeliveryRequestJob.fromMap(Map<String, dynamic> map) {
    final address = map['addresses'] as Map<String, dynamic>?;
    final commune = address?['communes'] as Map<String, dynamic>?;

    return DeliveryRequestJob(
      id: map['id'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      driverEarningShare:
          (map['driver_earning_share'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      acceptedAt: map['accepted_at'] == null
          ? null
          : DateTime.parse(map['accepted_at'] as String),
      addressText: address?['address_text'] as String?,
      communeName: commune?['name'] as String?,
      customerPhone: address?['phone'] as String?,
    );
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'مقبول';
      case 'delivered':
        return 'تم التسليم ✅';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }
}
