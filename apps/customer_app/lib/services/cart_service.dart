import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// نتيجة محاولة إضافة منتج للسلة — تسمح للواجهة بمعرفة ماذا حدث بالضبط
/// (خصوصًا حالة "منتج من محل آخر") بدون رمي استثناءات.
enum AddToCartResult { added, quantityIncreased, differentMerchantConflict }

const _prefsKey = 'cart_v1';

/// يدير سلة العميل بالكامل. القاعدة الأهم (من PHASE 1):
/// الطلب الواحد يجب أن يكون من تاجر واحد فقط. إذا حاول العميل إضافة
/// منتج من محل مختلف، نرفض بوضوح ونعطي الواجهة فرصة لسؤاله قبل إفراغ السلة.
///
/// تُحفَظ السلة محليًا (SharedPreferences) بعد كل تعديل، وتُسترجَع تلقائيًا
/// عند بدء التطبيق — إغلاق التطبيق أثناء التسوق لم يعد يفرغ السلة بصمت.
/// الحفظ/الاسترجاع لا يرميان استثناءً أبدًا (نفس فلسفة باقي الخدمات هنا):
/// فشل القراءة/الكتابة يعني ببساطة سلة فارغة، وليس تعطّل التطبيق.
class CartService extends ChangeNotifier {
  String? _merchantId;
  String? _merchantName;
  final List<CartItem> _items = [];

  CartService() {
    unawaited(_restore());
  }

  String? get merchantId => _merchantId;
  String? get merchantName => _merchantName;
  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final itemRows = map['items'] as List? ?? [];
      if (itemRows.isEmpty) return;

      // القراءة async — إن كان المستخدم أضاف منتجًا يدويًا قبل اكتمالها
      // (مسار نادر لكن ممكن)، لا نُلحق فوقه بيانات قديمة قد تخلط بين
      // محلَّين أو تكرّر المنتجات؛ ما بُني للتو فعليًا هو الأحدث دائمًا.
      if (_items.isNotEmpty) return;

      _merchantId = map['merchantId'] as String?;
      _merchantName = map['merchantName'] as String?;
      _items.addAll(
        itemRows.map(
          (row) => CartItem(
            productId: row['productId'] as String,
            productName: row['productName'] as String,
            unitPrice: (row['unitPrice'] as num).toDouble(),
            quantity: row['quantity'] as int,
          ),
        ),
      );
      notifyListeners();
    } catch (_) {
      // فشل الاسترجاع (بيانات تالفة، إصدار قديم غير متوافق...) — سلة
      // فارغة أفضل من تعطّل شاشة البداية.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await prefs.remove(_prefsKey);
        return;
      }
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'merchantId': _merchantId,
          'merchantName': _merchantName,
          'items': _items
              .map(
                (item) => {
                  'productId': item.productId,
                  'productName': item.productName,
                  'unitPrice': item.unitPrice,
                  'quantity': item.quantity,
                },
              )
              .toList(),
        }),
      );
    } catch (_) {
      // فشل الحفظ لا يجب أن يمنع تحديث السلة في الواجهة — فقط لن تُستعاد
      // بعد إعادة تشغيل التطبيق هذه المرة.
    }
  }

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
        unawaited(_persist());
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
      unawaited(_persist());
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
    unawaited(_persist());
  }

  void increaseQuantity(String productId) {
    final item = _items.firstWhere((item) => item.productId == productId);
    item.quantity += 1;
    notifyListeners();
    unawaited(_persist());
  }

  void decreaseQuantity(String productId) {
    final item = _items.firstWhere((item) => item.productId == productId);
    if (item.quantity <= 1) {
      removeItem(productId);
      return;
    }
    item.quantity -= 1;
    notifyListeners();
    unawaited(_persist());
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    if (_items.isEmpty) {
      _merchantId = null;
      _merchantName = null;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _items.clear();
    _merchantId = null;
    _merchantName = null;
    notifyListeners();
    unawaited(_persist());
  }
}
