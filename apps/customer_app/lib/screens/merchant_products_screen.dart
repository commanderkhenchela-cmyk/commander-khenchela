import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';

/// شاشة منتجات محل واحد، مرتّبة، بسيطة، بدون تعقيد.
class MerchantProductsScreen extends StatefulWidget {
  final String merchantId;
  final String storeName;

  const MerchantProductsScreen({
    super.key,
    required this.merchantId,
    required this.storeName,
  });

  @override
  State<MerchantProductsScreen> createState() =>
      _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final data = await Supabase.instance.client
        .from('products')
        .select('id, name, description, price')
        .eq('merchant_id', widget.merchantId)
        .eq('is_active', true)
        .order('name');

    return (data as List)
        .map((row) => Product.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _addToCart(Product product) {
    final cart = context.read<CartService>();
    final result = cart.addProduct(
      product: product,
      merchantId: widget.merchantId,
      merchantName: widget.storeName,
    );

    if (result == AddToCartResult.differentMerchantConflict) {
      _showDifferentMerchantDialog(product, cart);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('أُضيف "${product.name}" إلى السلة'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// القاعدة من PHASE 1: الطلب الواحد من تاجر واحد فقط. هذا الحوار يشرح
  /// الموقف بوضوح ويعطي المستخدم خيارًا صريحًا، بدل رفض صامت أو خلط تلقائي.
  void _showDifferentMerchantDialog(Product product, CartService cart) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سلتك من محل آخر'),
        content: Text(
          'سلتك تحتوي منتجات من "${cart.merchantName}". '
          'لا يمكن الطلب من محلّين في نفس الوقت. '
          'هل تريد إفراغ السلة وإضافة هذا المنتج من "${widget.storeName}" بدلاً منها؟',
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
                merchantName: widget.storeName,
              );
              Navigator.of(dialogContext).pop();
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
    final cart = context.watch<CartService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              if (cart.itemCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.black45,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذّر تحميل منتجات هذا المحل.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _productsFuture = _fetchProducts();
                        });
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return const Center(
              child: Text('لا توجد منتجات متاحة في هذا المحل حاليًا.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  subtitle: product.description == null
                      ? null
                      : Text(product.description!),
                  trailing: SizedBox(
                    width: 84,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(0)} دج',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: theme.colorScheme.primary,
                          ),
                          iconSize: 28,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _addToCart(product),
                          tooltip: 'أضف للسلة',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
