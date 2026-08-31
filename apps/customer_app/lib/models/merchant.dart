import 'merchant_business_hours.dart';
import '../utils/merchant_open_status.dart';

/// نموذج بسيط يمثّل محلًا، مطابق لجدول merchants في قاعدة البيانات.
class Merchant {
  final String id;
  final String storeName;
  final String? communeName;
  final String? phone;
  final List<MerchantBusinessHours> businessHours;
  final double? latitude;
  final double? longitude;
  final String? logoUrl;
  final String? coverUrl;
  final double ratingAvg;
  final int ratingCount;
  final bool isManuallyOpen;

  const Merchant({
    required this.id,
    required this.storeName,
    this.communeName,
    this.phone,
    this.businessHours = const [],
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.coverUrl,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isManuallyOpen = true,
  });

  /// لا نعرض شارة تقييم أبدًا بلا تقييمات حقيقية (0.0 وهمي بلا معنى).
  bool get hasRating => ratingCount > 0;

  /// true = مفتوح الآن، false = مغلق الآن، null = لا معلومة كافية (لم
  /// يحفظ التاجر ساعات عمله بعد) — يجب إخفاء أي شارة في حالة null.
  ///
  /// isManuallyOpen (عمود merchants.is_open، migration 20260903000000)
  /// تبديل يدوي من لوحة تحكم التاجر: عندما يكون false فالتاجر أغلق
  /// يدويًا الآن — نتيجة قطعية (مغلق) بغض النظر عن ساعات العمل. عندما
  /// يكون true (الافتراضي، ولا قيمة موجودة بعد قبل توفّر العمود) لا
  /// تقييد يدوي، فتُحسَب الحالة من ساعات العمل تمامًا كما كانت دائمًا —
  /// لا تغيير في السلوك لأي تاجر لم يستخدم هذا التبديل. بهذا لا يمكن
  /// للتبديل اليدوي أبدًا إجبار "مفتوح" خارج الساعات المصرَّح بها، فقط
  /// إغلاق إضافي فوقها.
  bool? get isOpenNow {
    if (!isManuallyOpen) return false;
    return MerchantOpenStatus.isOpenNow(businessHours);
  }

  /// true إذا حفظ التاجر موقعه الجغرافي — شرط ظهوره في قسم "الأقرب إليك".
  bool get hasLocation => latitude != null && longitude != null;

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
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      logoUrl: map['logo_url'] as String?,
      coverUrl: map['cover_url'] as String?,
      ratingAvg: (map['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
      isManuallyOpen: map['is_open'] as bool? ?? true,
    );
  }
}
