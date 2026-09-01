import '../l10n/app_localizations.dart';

/// نموذج طلب "اطلب أي شيء" — راجع migration
/// 20260905000000_delivery_requests لدورة الحياة الكاملة (pending ->
/// accepted -> delivered، أو pending -> cancelled). لا سعر غرض هنا إطلاقًا
/// (يُسوَّى نقدًا مباشرة بين العميل والموصّل)، فقط رسم التوصيل الذي
/// تحسبه المنصّة.
class DeliveryRequest {
  final String id;
  final String description;
  final String status;
  final double deliveryFee;
  final String deliveryFeeMethod;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? addressText;
  final String? communeName;

  const DeliveryRequest({
    required this.id,
    required this.description,
    required this.status,
    required this.deliveryFee,
    required this.deliveryFeeMethod,
    required this.createdAt,
    this.acceptedAt,
    this.addressText,
    this.communeName,
  });

  /// رسم توصيل حقيقي قابل للعرض؟ 'unconfigured' يعني لا إعداد فعّال بعد
  /// (راجع calculate_delivery_fee) — نفس منطق hasRealFee فـ checkout_screen.
  bool get hasRealFee => deliveryFeeMethod != 'unconfigured' && deliveryFee > 0;

  factory DeliveryRequest.fromMap(Map<String, dynamic> map) {
    final addressRow = map['addresses'] as Map<String, dynamic>?;
    final communeRow = addressRow?['communes'] as Map<String, dynamic>?;

    return DeliveryRequest(
      id: map['id'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      deliveryFeeMethod: map['delivery_fee_method'] as String? ?? 'unconfigured',
      createdAt: DateTime.parse(map['created_at'] as String),
      acceptedAt: map['accepted_at'] == null
          ? null
          : DateTime.parse(map['accepted_at'] as String),
      addressText: addressRow?['address_text'] as String?,
      communeName: communeRow?['name'] as String?,
    );
  }

  static String statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.deliveryRequestStatusPending;
      case 'accepted':
        return l10n.deliveryRequestStatusAccepted;
      case 'delivered':
        return l10n.deliveryRequestStatusDelivered;
      case 'cancelled':
        return l10n.deliveryRequestStatusCancelled;
      default:
        return status;
    }
  }
}
