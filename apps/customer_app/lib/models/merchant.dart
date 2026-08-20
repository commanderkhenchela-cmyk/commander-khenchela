import 'merchant_business_hours.dart';
import '../utils/merchant_open_status.dart';

/// نموذج بسيط يمثّل محلًا، مطابق لجدول merchants في قاعدة البيانات.
class Merchant {
  final String id;
  final String storeName;
  final String? communeName;
  final String? phone;
  final List<MerchantBusinessHours> businessHours;

  const Merchant({
    required this.id,
    required this.storeName,
    this.communeName,
    this.phone,
    this.businessHours = const [],
  });

  /// true = مفتوح الآن، false = مغلق الآن، null = لا معلومة كافية (لم
  /// يحفظ التاجر ساعات عمله بعد) — يجب إخفاء أي شارة في حالة null.
  bool? get isOpenNow => MerchantOpenStatus.isOpenNow(businessHours);

  factory Merchant.fromMap(Map<String, dynamic> map) {
    final commune = map['communes'] as Map<String, dynamic>?;
    final hoursRows = map['merchant_business_hours'] as List<dynamic>?;

    return Merchant(
      id: map['id'] as String,
      storeName: map['store_name'] as String,
      communeName: commune?['name'] as String?,
      phone: map['phone'] as String?,
      businessHours: hoursRows == null
          ? const []
          : hoursRows
                .map(
                  (row) => MerchantBusinessHours.fromMap(
                    row as Map<String, dynamic>,
                  ),
                )
                .toList(),
    );
  }
}
