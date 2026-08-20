/// نموذج بسيط يمثّل منتجًا، مطابق لجدول products في قاعدة البيانات.
class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? categoryName;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.categoryName,
    this.imageUrl,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final category = map['categories'] as Map<String, dynamic>?;
    final images = map['product_images'] as List?;

    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      categoryName: category?['name'] as String?,
      imageUrl: (images != null && images.isNotEmpty)
          ? images.first['image_url'] as String?
          : null,
    );
  }
}
