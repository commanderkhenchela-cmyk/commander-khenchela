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
  final DateTime? statusOverriddenAt;

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
    this.statusOverriddenAt,
  });

  /// لا نعرض شارة تقييم أبدًا بلا تقييمات حقيقية (0.0 وهمي بلا معنى).
  bool get hasRating => ratingCount > 0;

  /// true = مفتوح الآن، false = مغلق الآن، null = لا معلومة كافية —
  /// يجب إخفاء أي شارة في حالة null، لا تخمين "مغلق" ظلمًا بالمحل.
  ///
  /// مصدر الحقيقة يُحدَّد بـ statusOverriddenAt (عمود merchants.
  /// status_overridden_at، migration 20260904000000) — الطابع الزمني
  /// لآخر ضغطة فعلية على زر التبديل اليدوي في لوحة التاجر:
  /// - null (لم يُضغَط الزر إطلاقًا) → تلقائي بالكامل حسب ساعات العمل
  ///   الحقيقية (merchant_business_hours عبر MerchantOpenStatus) — لا
  ///   افتراض "مفتوح" بلا دليل؛ بلا ساعات محفوظة أيضًا → null (إخفاء).
  /// - غير null (استُخدم التبديل مرة واحدة على الأقل) → isManuallyOpen
  ///   وحده هو مصدر الحقيقة من تلك اللحظة، بأولوية *مطلقة* فوق ساعات
  ///   العمل في الاتجاهين (لا يمكن لساعات العمل نقض "مفتوح" اليدوي، ولا
  ///   لـ"مغلق" اليدوي أن يُنقَض بساعات عمل جارية) — هذا يحقق حرفيًا
  ///   "Manual Override له الأولوية على أوقات العمل" كما طُلب صراحةً.
  bool? get isOpenNow {
    if (statusOverriddenAt != null) return isManuallyOpen;
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
      statusOverriddenAt: map['status_overridden_at'] == null
          ? null
          : DateTime.parse(map['status_overridden_at'] as String),
    );
  }
}
