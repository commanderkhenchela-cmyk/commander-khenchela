import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/merchant_views_service.dart';
import '../widgets/merchant_logo.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

/// شاشة منتجات محل واحد، مرتّبة، بسيطة، بدون تعقيد.
///
/// logoUrl/coverUrl اختياريان، يُمرَّران من الشاشة المستدعية (التي تملك
/// أصلًا كائن Merchant الكامل) — بدون أي استعلام إضافي هنا لجلبهما. عند
/// غيابهما (لم يرفع التاجر صورًا بعد) لا تظهر لافتة الغلاف إطلاقًا، بدل
/// عرض شكل احتياطي فارغ.
class MerchantProductsScreen extends StatefulWidget {
  final String merchantId;
  final String storeName;
  final String? logoUrl;
  final String? coverUrl;

  const MerchantProductsScreen({
    super.key,
    required this.merchantId,
    required this.storeName,
    this.logoUrl,
    this.coverUrl,
  });

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
    // مستقل تمامًا عن تحميل المنتجات — لا ننتظره ولا يؤثر على الشاشة
    // بأي شكل حتى لو فشل (راجع فلسفة MerchantViewsService).
    MerchantViewsService.recordView(widget.merchantId);
  }

  Future<List<Product>> _fetchProducts() async {
    final data = await Supabase.instance.client
        .from('products')
        .select(
          'id, name, description, price, categories(name), product_images(image_url)',
        )
        .eq('merchant_id', widget.merchantId)
        .eq('is_active', true)
        .order('name');

    return (data as List)
        .map((row) => Product.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// يجمّع المنتجات حسب التصنيف، ويرتّب التصنيفات أبجديًا، حتى يسهل على
  /// العميل تصفّح محل فيه منتجات كثيرة ومتنوعة بدل قائمة طويلة واحدة.
  Map<String, List<Product>> _groupByCategory(List<Product> products) {
    final grouped = <String, List<Product>>{};

    final otherLabel = AppLocalizations.of(context).otherCategoryLabel;
    for (final product in products) {
      final category = product.categoryName ?? otherLabel;
      grouped.putIfAbsent(category, () => []).add(product);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final key in sortedKeys) key: grouped[key]!};
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
        content: Text(
          AppLocalizations.of(context).addedToCartMessage(product.name),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// القاعدة من PHASE 1: الطلب الواحد من تاجر واحد فقط. هذا الحوار يشرح
  /// الموقف بوضوح ويعطي المستخدم خيارًا صريحًا، بدل رفض صامت أو خلط تلقائي.
  void _showDifferentMerchantDialog(Product product, CartService cart) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.differentMerchantCartTitle),
        content: Text(
          l10n.differentMerchantCartMessage(
            cart.merchantName ?? '',
            widget.storeName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancelAction),
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
                SnackBar(content: Text(l10n.addedToCartMessage(product.name))),
              );
            },
            child: Text(l10n.clearCartAndAddAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
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
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _StoreCoverBanner(logoUrl: widget.logoUrl, coverUrl: widget.coverUrl),
          Expanded(
            child: FutureBuilder<List<Product>>(
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
                          Text(
                            l10n.merchantProductsLoadError,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _productsFuture = _fetchProducts();
                              });
                            },
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data ?? [];

                if (products.isEmpty) {
                  return Center(child: Text(l10n.noProductsMessage));
                }

                final grouped = _groupByCategory(products);
                // تسطيح الأقسام لعنصر واحد: عنوان تصنيف (String) أو منتج (Product)،
                // حتى نستخدم ListView.builder عادية بدل ListView متداخلة.
                final flatItems = <Object>[];
                for (final entry in grouped.entries) {
                  flatItems.add(entry.key);
                  flatItems.addAll(entry.value);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: flatItems.length,
                  itemBuilder: (context, index) {
                    final item = flatItems[index];

                    if (item is String) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : 20,
                          bottom: 8,
                        ),
                        child: Text(
                          item,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }

                    final product = item as Product;
                    // بناء يدوي بـ Row بدل ListTile: تجنّبًا لمشكلة "overflow"
                    // التي ظهرت فعليًا على الجهاز الحقيقي مع محتوى trailing
                    // متعدد الأسطر (السعر + زر الإضافة) داخل ListTile.
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: product,
                                merchantId: widget.merchantId,
                                merchantName: widget.storeName,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                product.imageUrl != null
                                    ? Hero(
                                        tag: 'product-image-${product.id}',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: product.imageUrl!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                _ProductIcon(
                                                  color: theme
                                                      .colorScheme
                                                      .primary,
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    _ProductIcon(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                          ),
                                        ),
                                      )
                                    : _ProductIcon(
                                        color: theme.colorScheme.primary,
                                      ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        product.name,
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      if (product.description != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          product.description!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: Colors.black54),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.currencyAmount(
                                          product.price.toStringAsFixed(0),
                                        ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                  onPressed: () => _addToCart(product),
                                  tooltip: l10n.addToCartTooltip,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// لافتة أعلى صفحة المحل: صورة الغلاف (إن رُفعت) مع الشعار متراكبًا فوقها
/// أسفلها — تختفي بالكامل إن لم يرفع التاجر أيًا من الصورتين، بدل عرض
/// شكل احتياطي فارغ لا فائدة منه.
class _StoreCoverBanner extends StatelessWidget {
  final String? logoUrl;
  final String? coverUrl;

  const _StoreCoverBanner({required this.logoUrl, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final logo = logoUrl;
    final cover = coverUrl;
    if (logo == null && cover == null) return const SizedBox.shrink();

    return SizedBox(
      height: logo != null ? 128 : 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: logo != null ? 28 : 0,
            child: cover == null
                ? Container(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.08),
                  )
                : CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.08),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.08),
                    ),
                  ),
          ),
          if (logo != null)
            Positioned(
              right: 16,
              bottom: 0,
              child: MerchantLogo(
                url: logo,
                size: 64,
                iconSize: 30,
                borderRadius: 18,
              ),
            ),
        ],
      ),
    );
  }
}

/// أيقونة بديلة عند عدم وجود صورة للمنتج (أو تعذّر تحميلها).
class _ProductIcon extends StatelessWidget {
  final Color color;

  const _ProductIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(Icons.shopping_bag_outlined, color: color),
    );
  }
}
