/// نموذج عنوان توصيل، مطابق لجدول addresses في قاعدة البيانات.
/// V1 كان يكتفي بعنوان واحد فقط لكل عميل؛ الآن يدعم عدة عناوين
/// (مثال: "المنزل"، "العمل") يختار العميل بينها عند كل طلب.
class DeliveryAddress {
  final String id;
  final int communeId;
  final String communeName;
  final String addressText;
  final String phone;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  const DeliveryAddress({
    required this.id,
    required this.communeId,
    required this.communeName,
    required this.addressText,
    required this.phone,
    required this.isDefault,
    this.latitude,
    this.longitude,
  });

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      id: map['id'] as String,
      communeId: map['commune_id'] as int,
      communeName: (map['communes'] as Map<String, dynamic>)['name'] as String,
      addressText: map['address_text'] as String,
      phone: map['phone'] as String? ?? '',
      isDefault: map['is_default'] as bool? ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
