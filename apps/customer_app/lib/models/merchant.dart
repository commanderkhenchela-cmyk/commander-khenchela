/// نموذج بسيط يمثّل محلًا، مطابق لجدول merchants في قاعدة البيانات.
class Merchant {
  final String id;
  final String storeName;

  const Merchant({required this.id, required this.storeName});

  factory Merchant.fromMap(Map<String, dynamic> map) {
    return Merchant(
      id: map['id'] as String,
      storeName: map['store_name'] as String,
    );
  }
}
