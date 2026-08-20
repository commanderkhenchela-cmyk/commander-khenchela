/// نموذج عنوان توصيل، مطابق لجدول addresses في قاعدة البيانات.
class DeliveryAddress {
  final String id;
  final int communeId;
  final String communeName;
  final String addressText;
  final String phone;

  const DeliveryAddress({
    required this.id,
    required this.communeId,
    required this.communeName,
    required this.addressText,
    required this.phone,
  });

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      id: map['id'] as String,
      communeId: map['commune_id'] as int,
      communeName: (map['communes'] as Map<String, dynamic>)['name'] as String,
      addressText: map['address_text'] as String,
      phone: map['phone'] as String? ?? '',
    );
  }
}
