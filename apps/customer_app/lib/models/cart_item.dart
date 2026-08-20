/// عنصر واحد داخل السلة — منتج + الكمية المطلوبة منه.
class CartItem {
  final String productId;
  final String productName;
  final double unitPrice;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;
}
