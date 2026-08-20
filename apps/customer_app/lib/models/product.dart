/// نموذج بسيط يمثّل منتجًا، مطابق لجدول products في قاعدة البيانات.
class Product {
  final String id;
  final String name;
  final String? description;
  final double price;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
    );
  }
}
