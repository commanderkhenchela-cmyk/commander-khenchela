import 'package:customer_app/models/product.dart';
import 'package:customer_app/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _p1 = Product(id: 'p1', name: 'سكر 1 كغ', price: 150);
const _p2 = Product(id: 'p2', name: 'زيت 1 لتر', price: 400);
const _p3 = Product(id: 'p3', name: 'خبز', price: 30);

void main() {
  // CartService._restore() يقرأ SharedPreferences فور الإنشاء — بدون هذا
  // الموك، أول استدعاء لـ getInstance() في بيئة الاختبار يفشل.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CartService.addProduct', () {
    test('إضافة أول منتج تنشئ السلة وتُرجع added', () {
      final cart = CartService();
      final result = cart.addProduct(
        product: _p1,
        merchantId: 'm1',
        merchantName: 'بقالة الأمل',
      );

      expect(result, AddToCartResult.added);
      expect(cart.merchantId, 'm1');
      expect(cart.items, hasLength(1));
      expect(cart.itemCount, 1);
      expect(cart.subtotal, 150);
    });

    test('إضافة نفس المنتج مرة ثانية تزيد الكمية بدل تكرار السطر', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');
      final result = cart.addProduct(
        product: _p1,
        merchantId: 'm1',
        merchantName: 'بقالة',
      );

      expect(result, AddToCartResult.quantityIncreased);
      expect(cart.items, hasLength(1));
      expect(cart.items.first.quantity, 2);
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 300);
    });

    test('منتج ثانٍ من نفس المحل يُضاف عاديًا كسطر جديد', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');
      final result = cart.addProduct(
        product: _p2,
        merchantId: 'm1',
        merchantName: 'بقالة',
      );

      expect(result, AddToCartResult.added);
      expect(cart.items, hasLength(2));
      expect(cart.subtotal, 550);
    });

    test(
      'منتج من محل مختلف يُرفض تلقائيًا (قاعدة تاجر واحد لكل طلب) ولا يُضاف',
      () {
        final cart = CartService()
          ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');
        final result = cart.addProduct(
          product: _p3,
          merchantId: 'm2',
          merchantName: 'مخبزة',
        );

        expect(result, AddToCartResult.differentMerchantConflict);
        // السلة تبقى كما هي تمامًا — لا تُفرَّغ ولا يُضاف المنتج الجديد.
        expect(cart.items, hasLength(1));
        expect(cart.merchantId, 'm1');
      },
    );
  });

  group('CartService.clearAndAddProduct', () {
    test('يُفرغ السلة القديمة ويبدأ سلة جديدة من محل آخر', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');

      cart.clearAndAddProduct(
        product: _p3,
        merchantId: 'm2',
        merchantName: 'مخبزة',
      );

      expect(cart.merchantId, 'm2');
      expect(cart.merchantName, 'مخبزة');
      expect(cart.items, hasLength(1));
      expect(cart.items.first.productId, 'p3');
    });
  });

  group('CartService quantity/removal', () {
    test('increaseQuantity/decreaseQuantity يعدّلان الكمية والمجموع', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');

      cart.increaseQuantity('p1');
      expect(cart.items.first.quantity, 2);

      cart.decreaseQuantity('p1');
      expect(cart.items.first.quantity, 1);
    });

    test('decreaseQuantity عند الكمية 1 يحذف السطر كاملًا', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');

      cart.decreaseQuantity('p1');

      expect(cart.isEmpty, isTrue);
      expect(cart.merchantId, isNull);
    });

    test('removeItem لآخر منتج يفرّغ merchantId/merchantName أيضًا', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');

      cart.removeItem('p1');

      expect(cart.isEmpty, isTrue);
      expect(cart.merchantId, isNull);
      expect(cart.merchantName, isNull);
    });

    test('clear يفرّغ السلة كاملة', () {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة')
        ..addProduct(product: _p2, merchantId: 'm1', merchantName: 'بقالة');

      cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.items, isEmpty);
      expect(cart.merchantId, isNull);
    });
  });

  group('CartService persistence', () {
    test(
      'السلة تُحفَظ محليًا وتُسترجَع فـ نسخة جديدة (نجاة من إغلاق التطبيق)',
      () async {
        final cart = CartService()
          ..addProduct(
            product: _p1,
            merchantId: 'm1',
            merchantName: 'بقالة الأمل',
          )
          ..addProduct(
            product: _p2,
            merchantId: 'm1',
            merchantName: 'بقالة الأمل',
          );

        // الحفظ غير متزامن (unawaited) — ننتظر دورة أحداث كافية لإتمامه.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final restored = CartService();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(restored.merchantId, 'm1');
        expect(restored.merchantName, 'بقالة الأمل');
        expect(restored.items, hasLength(2));
        expect(restored.subtotal, cart.subtotal);
      },
    );

    test('سلة فارغة (بعد clear) لا تُسترجَع فـ نسخة جديدة', () async {
      final cart = CartService()
        ..addProduct(product: _p1, merchantId: 'm1', merchantName: 'بقالة');
      await Future<void>.delayed(Duration.zero);

      cart.clear();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final restored = CartService();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(restored.isEmpty, isTrue);
    });
  });
}
