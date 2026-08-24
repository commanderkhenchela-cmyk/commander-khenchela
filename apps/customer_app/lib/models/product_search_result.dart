import 'product.dart';

/// نتيجة بحث عن منتج — تضمّ المنتج نفسه + هوية المحل المالك له (غير
/// موجودة في Product نفسه أصلًا، لأنه عادة يُعرض ضمن سياق محل معروف
/// مسبقًا؛ نتيجة البحث تحتاجها صراحة لأنها قد تجمع منتجات من محلّات
/// متعددة في نفس القائمة).
class ProductSearchResult {
  final Product product;
  final String merchantId;
  final String merchantName;

  const ProductSearchResult({
    required this.product,
    required this.merchantId,
    required this.merchantName,
  });

  factory ProductSearchResult.fromMap(Map<String, dynamic> map) {
    final merchant = map['merchants'] as Map<String, dynamic>;
    return ProductSearchResult(
      product: Product.fromMap(map),
      merchantId: merchant['id'] as String,
      merchantName: merchant['store_name'] as String,
    );
  }
}
