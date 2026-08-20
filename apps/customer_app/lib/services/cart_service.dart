import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// نتيجة محاولة إضافة منتج للسلة — تسمح للواجهة بمعرفة ماذا حدث بالضبط
/// (خصوصًا حالة "منتج من محل آخر") بدون رمي استثناءات.
enum AddToCartResult { added, quantityIncreased, differentMerchantConflict }

/// يدير سلة العميل بالكامل. القاعدة الأهم (من PHASE 1):
/// الطلب الواحد يجب أن يكون من تاجر واحد فقط. إذا حاول العميل إضافة
/// منتج من محل مختلف، نرفض بوضوح ونعطي الواجهة فرصة لسؤاله قبل إفراغ السلة.
class CartService extends ChangeNotifier {
  String? _merchantId;
  String? _merchantName;
  final List<CartItem> _items = [];

  String? get merchantId => _merchantId;
  String? get merchantName => _merchantName;
  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  AddToCartResult addProduct({
    required Product product,
    required String merchantId,
    required String merchantName,
  }) {
    // سلة فارغة أو نفس المحل: إضافة عادية
    if (_items.isEmpty || _merchantId == merchantId) {
      _merchantId = merchantId;
      _merchantName = merchantName;

      final existingIndex = _items.indexWhere(
        (item) => item.productId == product.id,
      );

      if (existingIndex != -1) {
        _items[existingIndex].quantity += 1;
        notifyListeners();
        return AddToCartResult.quantityIncreased;
      }

      _items.add(
        CartItem(
          productId: product.id,
          productName: product.name,
          unitPrice: product.price,
        ),
      );
      notifyListeners();
      return AddToCartResult.added;
    }

    // محل مختلف: نرفض الإضافة التلقائية، نترك القرار للمستخدم عبر الواجهة
    return AddToCartResult.differentMerchantConflict;
  }

  /// تُستدعى بعد موافقة المستخدم صراحة على إفراغ السلة لبدء طلب من محل جديد.
  void clearAndAddProduct({
    required Product product,
    required String merchantId,
    required String merchantName,
  }) {
    _items.clear();
    _merchantId = merchantId;
    _merchantName = merchantName;
    _items.add(
      CartItem(
        productId: product.id,
        productName: product.name,
        unitPrice: product.price,
      ),
    );
    notifyListeners();
  }

  void increaseQuantity(String productId) {
    final item = _items.firstWhere((item) => item.productId == productId);
    item.quantity += 1;
    notifyListeners();
  }

  void decreaseQuantity(String productId) {
    final item = _items.firstWhere((item) => item.productId == productId);
    if (item.quantity <= 1) {
      removeItem(productId);
      return;
    }
    item.quantity -= 1;
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    if (_items.isEmpty) {
      _merchantId = null;
      _merchantName = null;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _merchantId = null;
    _merchantName = null;
    notifyListeners();
  }
}
