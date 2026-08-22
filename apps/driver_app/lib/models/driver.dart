/// ملف الموصّل نفسه — صفّ واحد في جدول drivers مطابق للحساب الحالي
/// (RLS drivers_select_own تحصر النتيجة على صاحب الجلسة تلقائيًا).
class Driver {
  final String id;
  final String fullName;
  final String phone;
  final String vehicleType;
  final String status;
  final bool isOnline;

  const Driver({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.status,
    required this.isOnline,
  });

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      vehicleType: map['vehicle_type'] as String,
      status: map['status'] as String,
      isOnline: map['is_online'] as bool,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
