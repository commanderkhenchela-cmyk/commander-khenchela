/// ملف الموصّل نفسه — صفّ واحد في جدول drivers مطابق للحساب الحالي
/// (RLS drivers_select_own تحصر النتيجة على صاحب الجلسة تلقائيًا).
class Driver {
  final String id;
  final String fullName;
  final String phone;
  final String vehicleType;
  final String? plateNumber;
  final String status;
  final bool isOnline;
  final double ratingAvg;
  final int ratingCount;

  const Driver({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.status,
    required this.isOnline,
    this.plateNumber,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      vehicleType: map['vehicle_type'] as String,
      plateNumber: map['plate_number'] as String?,
      status: map['status'] as String,
      isOnline: map['is_online'] as bool,
      ratingAvg: (map['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  /// راجع migration 20260910000000_driver_vehicle_types — نوع المركبة
  /// يحدّد أي مجمّع طلبات يراه هذا الحساب (RLS)، الواجهة هنا تعكس نفس
  /// الفصل فقط، لا تفرضه (الفرض الفعلي فـ القاعدة).
  bool get isBike => vehicleType == 'bike';
  bool get isCar => vehicleType == 'car';
  bool get isTruck => vehicleType == 'truck';
}
