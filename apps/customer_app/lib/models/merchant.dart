/// نموذج بسيط يمثّل محلًا، مطابق لجدول merchants في قاعدة البيانات.
class Merchant {
  final String id;
  final String storeName;
  final String? communeName;
  final String? phone;

  const Merchant({
    required this.id,
    required this.storeName,
    this.communeName,
    this.phone,
  });

  factory Merchant.fromMap(Map<String, dynamic> map) {
    final commune = map['communes'] as Map<String, dynamic>?;

    return Merchant(
      id: map['id'] as String,
      storeName: map['store_name'] as String,
      communeName: commune?['name'] as String?,
      phone: map['phone'] as String?,
    );
  }
}
