import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.storeName)),
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
                  trailing: Text(
                    '${product.price.toStringAsFixed(0)} دج',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
