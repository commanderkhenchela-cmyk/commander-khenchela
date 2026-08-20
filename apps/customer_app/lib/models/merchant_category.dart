/// تصنيف محل (مطاعم، بقالة، صيدليات...) — مطابق لجدول merchant_categories.
/// يختلف عن أي تصنيف منتجات داخل محل واحد؛ هذا تصنيف على مستوى التطبيق
/// كله، يُدار بالكامل من لوحة الإدارة (لا شيء هنا Hardcoded).
class MerchantCategory {
  final String id;
  final String name;
  final String icon;

  const MerchantCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory MerchantCategory.fromMap(Map<String, dynamic> map) {
    return MerchantCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
    );
  }
}
