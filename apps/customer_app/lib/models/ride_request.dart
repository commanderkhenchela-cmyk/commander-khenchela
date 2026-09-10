import '../l10n/app_localizations.dart';

/// نموذج طلب رحلة Taxi — راجع migration 20260906000000_ride_requests
/// لدورة الحياة الكاملة (pending -> accepted -> in_progress ->
/// completed، أو pending/accepted -> cancelled). الأجرة معروفة منذ
/// الإنشاء مباشرة (بخلاف DeliveryRequest) لأن نقطتَي الانطلاق والوجهة
/// كلتاهما معروفتان سلفًا.
class RideRequest {
  final String id;
  final String status;
  final double fare;
  final String fareMethod;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? driverId;
  final String? pickupAddressText;
  final String? pickupCommuneName;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffAddressText;
  final String? dropoffCommuneName;
  final double? dropoffLat;
  final double? dropoffLng;

  const RideRequest({
    required this.id,
    required this.status,
    required this.fare,
    required this.fareMethod,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.driverId,
    this.pickupAddressText,
    this.pickupCommuneName,
    this.pickupLat,
    this.pickupLng,
    this.dropoffAddressText,
    this.dropoffCommuneName,
    this.dropoffLat,
    this.dropoffLng,
  });

  /// موقع الموصّل الحيّ ذو معنى فقط أثناء هاتين المرحلتين — نفس شرط
  /// RLS drivers_select_via_assigned_ride بالضبط (migration
  /// 20260911000000)، لا داعي لطلب صفّ الموصّل خارجهما، RLS سترفضه
  /// أصلًا.
  bool get canTrackDriverLive =>
      driverId != null && (status == 'accepted' || status == 'in_progress');

  /// أجرة حقيقية قابلة للعرض؟ 'unconfigured' يعني لا إعداد فعّال بعد
  /// لخدمة taxi (راجع calculate_delivery_fee)، أو أحد العنوانين بلا
  /// إحداثيات محفوظة.
  bool get hasRealFare => fareMethod != 'unconfigured' && fare > 0;

  /// pending/accepted فقط يمكن إلغاؤهما ذاتيًا — راجع
  /// validate_ride_request_status_transition.
  bool get canBeCancelled => status == 'pending' || status == 'accepted';

  /// التقييم مسموح فقط لرحلة اكتملت فعليًا — نفس الشرط المطبَّق فـ RLS
  /// على جدول driver_reviews (راجع migration driver_reviews)، حتى لا
  /// يظهر زر تقييم يفشل عند الضغط عليه. status == 'completed' يستلزم
  /// driver_id غير null دائمًا (لا انتقال لـ completed بلا موصّل مُعيَّن).
  bool get canBeReviewed => status == 'completed';

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? addressOf(String key) =>
        map[key] as Map<String, dynamic>?;
    String? communeOf(Map<String, dynamic>? address) =>
        (address?['communes'] as Map<String, dynamic>?)?['name'] as String?;

    final pickup = addressOf('pickup_address');
    final dropoff = addressOf('dropoff_address');

    return RideRequest(
      id: map['id'] as String,
      status: map['status'] as String,
      fare: (map['fare'] as num?)?.toDouble() ?? 0,
      fareMethod: map['fare_method'] as String? ?? 'unconfigured',
      createdAt: DateTime.parse(map['created_at'] as String),
      acceptedAt: map['accepted_at'] == null
          ? null
          : DateTime.parse(map['accepted_at'] as String),
      startedAt: map['started_at'] == null
          ? null
          : DateTime.parse(map['started_at'] as String),
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      driverId: map['driver_id'] as String?,
      pickupAddressText: pickup?['address_text'] as String?,
      pickupCommuneName: communeOf(pickup),
      pickupLat: (pickup?['latitude'] as num?)?.toDouble(),
      pickupLng: (pickup?['longitude'] as num?)?.toDouble(),
      dropoffAddressText: dropoff?['address_text'] as String?,
      dropoffCommuneName: communeOf(dropoff),
      dropoffLat: (dropoff?['latitude'] as num?)?.toDouble(),
      dropoffLng: (dropoff?['longitude'] as num?)?.toDouble(),
    );
  }

  static String statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.rideStatusPending;
      case 'accepted':
        return l10n.rideStatusAccepted;
      case 'in_progress':
        return l10n.rideStatusInProgress;
      case 'completed':
        return l10n.rideStatusCompleted;
      case 'cancelled':
        return l10n.rideStatusCancelled;
      default:
        return status;
    }
  }
}

/// تقييم عميل واحد لرحلة مكتملة — قد لا يوجد بعد لرحلة معيَّنة (المستدعي
/// يتعامل مع null كـ "لم تُقيَّم بعد"). نفس بنية CustomerReview
/// (order_detail.dart) بالحرف، لكن على driver_reviews بدل reviews.
class DriverReview {
  final String id;
  final int rating;
  final String? comment;

  const DriverReview({required this.id, required this.rating, this.comment});

  factory DriverReview.fromMap(Map<String, dynamic> map) {
    return DriverReview(
      id: map['id'] as String,
      rating: (map['rating'] as num).toInt(),
      comment: map['comment'] as String?,
    );
  }
}
