/// رحلة Taxi كما يراها الموصّل — راجع migration
/// 20260906000000_ride_requests. بخلاف DeliveryRequestJob، عنوانا
/// الانطلاق والوجهة مرئيان حتى فـ المجمّع (قبل القبول) — الموصّل يحتاج
/// معرفة أين الراكب قبل قرار القبول (راجع تعليق الـ RLS فـ الـ migration).
class RideJob {
  final String id;
  final String status;
  final double fare;
  final double driverEarningShare;
  final DateTime createdAt;
  final String? pickupAddressText;
  final String? pickupCommuneName;
  final String? pickupPhone;
  final String? dropoffAddressText;
  final String? dropoffCommuneName;

  const RideJob({
    required this.id,
    required this.status,
    required this.fare,
    required this.driverEarningShare,
    required this.createdAt,
    this.pickupAddressText,
    this.pickupCommuneName,
    this.pickupPhone,
    this.dropoffAddressText,
    this.dropoffCommuneName,
  });

  factory RideJob.fromMap(Map<String, dynamic> map) {
    final pickup = map['pickup_address'] as Map<String, dynamic>?;
    final dropoff = map['dropoff_address'] as Map<String, dynamic>?;

    return RideJob(
      id: map['id'] as String,
      status: map['status'] as String,
      fare: (map['fare'] as num?)?.toDouble() ?? 0,
      driverEarningShare:
          (map['driver_earning_share'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      pickupAddressText: pickup?['address_text'] as String?,
      pickupCommuneName:
          (pickup?['communes'] as Map<String, dynamic>?)?['name'] as String?,
      pickupPhone: pickup?['phone'] as String?,
      dropoffAddressText: dropoff?['address_text'] as String?,
      dropoffCommuneName:
          (dropoff?['communes'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'مقبولة';
      case 'in_progress':
        return 'الرحلة جارية';
      case 'completed':
        return 'اكتملت ✅';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }
}
