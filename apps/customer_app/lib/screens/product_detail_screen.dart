import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cart_service.dart';

/// صفحة تفاصيل منتج حقيقية — راجع تقرير الفحص السابق: لم تكن موجودة
/// إطلاقًا (المنتجات كانت تُعرض فقط داخل قائمة MerchantProductsScreen).
///
/// تعرض فقط حقولًا موجودة فعليًا بجدول products (اسم/سعر/وصف/صورة) —
/// عمدًا **بدون** خصم/سعر قديم/متغيّرات (Variants)/خيارات/منتجات ذات
/// صلة/تقييمات لكل منتج: لا عمود لأي منها بقاعدة البيانات حاليًا (راجع
/// migration create_catalog)، وإضافتها بواجهة بلا بيانات حقيقية خداع
/// بصري، لا ميزة حقيقية. "المفضّلة" أيضًا غير موجودة هنا لنفس السبب —
/// جدول favorites الحالي على مستوى المحل فقط، لا يدعم منتجًا مفردًا.
///
/// "Quick Add" من القائمة يبقى يعمل كما هو تمامًا (بدون المرور بهذه
/// الشاشة) — هذه الشاشة إضافة اختيارية، وليست بديلاً إجباريًا له.
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String merchantId;
  final String merchantName;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _increment() => setState(() => _quantity++);

  void _decrement() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  void _addToCart() {
    final cart = context.read<CartService>();
    final result = cart.addProduct(
      product: widget.product,
      merchantId: widget.merchantId,
      merchantName: widget.merchantName,
    );

    if (result == AddToCartResult.differentMerchantConflict) {
      _showDifferentMerchantDialog(cart);
      return;
    }

    // addProduct تضيف بكمية 1 دائمًا (لا تُعدَّل — راجع تعليق CartService)؛
    // الكمية الإضافية المختارة هنا تُطبَّق عبر نفس increaseQuantity
    // المستخدَمة أصلًا في شاشة السلة، بدل تكرار منطق الإضافة.
    for (var i = 1; i < _quantity; i++) {
      cart.increaseQuantity(widget.product.id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('أُضيف "${widget.product.name}" إلى السلة'),
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.of(context).pop();
  }

  void _showDifferentMerchantDialog(CartService cart) {
    final product = widget.product;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سلتك من محل آخر'),
        content: Text(
          'سلتك تحتوي منتجات من "${cart.merchantName}". '
          'لا يمكن الطلب من محلّين في نفس الوقت. '
          'هل تريد إفراغ السلة وإضافة هذا المنتج من "${widget.merchantName}" بدلاً منها؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              cart.clearAndAddProduct(
                product: product,
                merchantId: widget.merchantId,
                merchantName: widget.merchantName,
              );
              for (var i = 1; i < _quantity; i++) {
                cart.increaseQuantity(product.id);
              }
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('أُضيف "${product.name}" إلى السلة')),
              );
            },
            child: const Text('نعم، إفراغ السلة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            flexibleSpace: FlexibleSpaceBar(
              background: product.imageUrl != null
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _ImagePlaceholder(color: theme.colorScheme.primary),
                    )
                  : _ImagePlaceholder(color: theme.colorScheme.primary),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${product.price.toStringAsFixed(0)} دج',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (product.description != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'الوصف',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), // مساحة فوق الشريط السفلي
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              _QuantityStepper(
                quantity: _quantity,
                onIncrement: _increment,
                onDecrement: _decrement,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addToCart,
                  child: const Text('أضف إلى السلة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final Color color;

  const _ImagePlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 64,
        color: color.withValues(alpha: 0.4),
      ),
    );
  }
}
