import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/merchant.dart';
import '../../../models/merchant_category.dart';
import '../../../screens/merchant_products_screen.dart';
import '../../../screens/merchants_screen.dart';
import '../../../screens/product_detail_screen.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/merchant_category_icon.dart';
import '../../../utils/pagination.dart';
import '../../../widgets/merchant_card.dart';
import '../../../widgets/search_field.dart';
import '../data/recent_searches_service.dart';
import '../data/search_stats_service.dart';
import '../domain/product_search_result.dart';

enum _ResultType { all, merchants, products, categories }

enum _SortOption { relevance, priceLowToHigh, priceHighToLow }

/// شاشة البحث العامة — تطوير حقيقي فوق البحث السابق (كان يجلب كل
/// المحلات والتصنيفات دفعة واحدة ويفلتر محليًا). الآن: استعلامات
/// مفلترة من الخادم مباشرة (ilike + limit)، بحث حقيقي عن منتجات أيضًا
/// (لم يكن موجودًا إطلاقًا)، بحث أخيرة محلية (SharedPreferences)، وبحث
/// شائع حقيقي عبر جدول search_queries الجديد (راجع migration
/// 20260825000000_search_queries) — لا بيانات ملفَّقة، العدّاد يُحدَّث
/// فقط عبر RPC محكومة عند بحث فعلي.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _minQueryLength = 2;
  static const _debounceDuration = Duration(milliseconds: 400);
  static const _productsPageSize = 15;

  final _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';
  _ResultType _typeFilter = _ResultType.all;
  _SortOption _sort = _SortOption.relevance;

  Future<List<String>>? _recentFuture;
  Future<List<String>>? _popularFuture;
  Future<_SearchResults>? _resultsFuture;

  // Pagination حقيقية من Supabase لنتائج المنتجات (الأكبر عادة بين
  // الأقسام الثلاثة) — لا تحميل دفعة واحدة لكل النتائج، فقط صفحة واحدة
  // إضافية (.range) عند طلب "تحميل المزيد" صراحة. راجع _loadMoreProducts.
  bool _isLoadingMoreProducts = false;
  bool _loadMoreProductsError = false;

  @override
  void initState() {
    super.initState();
    _recentFuture = RecentSearchesService.load();
    _popularFuture = SearchStatsService.fetchPopular();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final text = _controller.text.trim();
    _debounce?.cancel();

    if (text.isEmpty) {
      setState(() {
        _query = '';
        _resultsFuture = null;
      });
      return;
    }

    _debounce = Timer(_debounceDuration, () => _runSearch(text));
  }

  void _runSearch(String text) {
    if (text.length < _minQueryLength) {
      setState(() {
        _query = text;
        _resultsFuture = null;
      });
      return;
    }

    setState(() {
      _query = text;
      _resultsFuture = _search(text);
      _isLoadingMoreProducts = false;
      _loadMoreProductsError = false;
    });

    // لا تُنتظَر أبدًا — تسجيل إحصائي بحت، فشله لا يجب أن يؤثّر على
    // نتائج البحث المعروضة بأي شكل.
    unawaited(
      RecentSearchesService.add(text).then((updated) {
        if (mounted) setState(() => _recentFuture = Future.value(updated));
      }),
    );
    unawaited(SearchStatsService.record(text));
  }

  Future<_SearchResults> _search(String query) async {
    final client = Supabase.instance.client;
    final pattern = '%$query%';
    const merchantColumns =
        'id, store_name, phone, communes(name), latitude, longitude, '
        'logo_url, cover_url, rating_avg, rating_count, is_open, status_overridden_at, '
        'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

    final merchantsFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .ilike('store_name', pattern)
        .order('store_name')
        .limit(15);

    final categoriesFuture = client
        .from('merchant_categories')
        .select('id, name, icon')
        .eq('is_active', true)
        .ilike('name', pattern)
        .order('sort_order', ascending: true)
        .limit(10);

    final productsFuture = client
        .from('products')
        .select(
          'id, name, description, price, product_images(image_url), '
          'merchants(id, store_name)',
        )
        .eq('is_active', true)
        .ilike('name', pattern)
        .range(0, _productsPageSize - 1);

    final results = await Future.wait([
      merchantsFuture,
      categoriesFuture,
      productsFuture,
    ]);

    final productRows = results[2] as List;

    return _SearchResults(
      merchants: (results[0] as List)
          .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
          .toList(),
      categories: (results[1] as List)
          .map((row) => MerchantCategory.fromMap(row as Map<String, dynamic>))
          .toList(),
      products: productRows
          .map(
            (row) => ProductSearchResult.fromMap(row as Map<String, dynamic>),
          )
          .toList(),
      // صفحة كاملة (== حجم الصفحة) تعني على الأرجح وجود صفحة تالية —
      // نفس المنطق المتّبع في كل pagination بـ Supabase عبر .range، بلا
      // استعلام count إضافي منفصل غير ضروري لهذا الحجم من البيانات.
      hasMoreProducts: hasMorePages(
        fetchedCount: productRows.length,
        pageSize: _productsPageSize,
      ),
    );
  }

  /// يجلب صفحة إضافية واحدة من نتائج المنتجات فقط (الأكبر بين الأقسام
  /// الثلاثة عادة) عبر .range — لا يعيد تحميل القائمة كاملة، فقط
  /// يُلحِق العناصر الجديدة بنفس كائن النتائج المحمَّل مسبقًا.
  Future<void> _loadMoreProducts() async {
    final results = await _resultsFuture;
    if (!mounted || results == null || !results.hasMoreProducts) return;
    if (_isLoadingMoreProducts) return;

    setState(() {
      _isLoadingMoreProducts = true;
      _loadMoreProductsError = false;
    });

    try {
      final client = Supabase.instance.client;
      final pattern = '%$_query%';
      final from = results.products.length;
      final rows = await client
          .from('products')
          .select(
            'id, name, description, price, product_images(image_url), '
            'merchants(id, store_name)',
          )
          .eq('is_active', true)
          .ilike('name', pattern)
          .range(from, from + _productsPageSize - 1);

      final newItems = (rows as List)
          .map(
            (row) => ProductSearchResult.fromMap(row as Map<String, dynamic>),
          )
          .toList();

      results.products.addAll(newItems);
      results.hasMoreProducts = hasMorePages(
        fetchedCount: newItems.length,
        pageSize: _productsPageSize,
      );
    } catch (_) {
      if (mounted) setState(() => _loadMoreProductsError = true);
    } finally {
      if (mounted) setState(() => _isLoadingMoreProducts = false);
    }
  }

  void _refresh() {
    if (_query.length >= _minQueryLength) _runSearch(_query);
  }

  void _openMerchant(Merchant merchant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantProductsScreen(
          merchantId: merchant.id,
          storeName: merchant.storeName,
          logoUrl: merchant.logoUrl,
          coverUrl: merchant.coverUrl,
          isOpenNow: merchant.isOpenNow,
        ),
      ),
    );
  }

  void _openCategory(MerchantCategory category) {
    final locationName = AppLocalizations.of(context).wilayaName;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantsScreen(
          locationName: locationName,
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
  }

  void _openProduct(ProductSearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: result.product,
          merchantId: result.merchantId,
          merchantName: result.merchantName,
        ),
      ),
    );
  }

  void _applyRecentSearch(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _runSearch(query);
  }

  Future<void> _removeRecentSearch(String query) async {
    final updated = await RecentSearchesService.remove(query);
    if (mounted) setState(() => _recentFuture = Future.value(updated));
  }

  Future<void> _clearRecentSearches() async {
    await RecentSearchesService.clear();
    if (mounted) setState(() => _recentFuture = Future.value(const []));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: SearchField(
          controller: _controller,
          autofocus: true,
          hintText: l10n.searchHint,
        ),
      ),
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: _query.isEmpty
            ? _buildEmptyQueryState(l10n)
            : _buildResultsState(l10n),
      ),
    );
  }

  Widget _buildEmptyQueryState(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        FutureBuilder<List<String>>(
          future: _recentFuture,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (items.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionTitle(l10n.recentSearches),
                      TextButton(
                        onPressed: _clearRecentSearches,
                        child: Text(l10n.clearAll),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final query in items)
                        _SearchChip(
                          label: query,
                          onTap: () => _applyRecentSearch(query),
                          onDismiss: () => _removeRecentSearch(query),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<List<String>>(
          future: _popularFuture,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (items.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(l10n.popularSearches),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final query in items)
                      _SearchChip(
                        label: query,
                        onTap: () => _applyRecentSearch(query),
                        icon: Icons.trending_up_rounded,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        FutureBuilder<List<String>>(
          future: _recentFuture,
          builder: (context, recentSnap) {
            return FutureBuilder<List<String>>(
              future: _popularFuture,
              builder: (context, popularSnap) {
                final noRecent = (recentSnap.data ?? const []).isEmpty;
                final noPopular = (popularSnap.data ?? const []).isEmpty;
                final stillLoading =
                    recentSnap.connectionState == ConnectionState.waiting ||
                    popularSnap.connectionState == ConnectionState.waiting;
                if (stillLoading || !(noRecent && noPopular)) {
                  return const SizedBox.shrink();
                }
                return _CenterMessage(
                  icon: Icons.search_rounded,
                  message: l10n.searchEmptyPrompt,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildResultsState(AppLocalizations l10n) {
    return FutureBuilder<_SearchResults>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (_resultsFuture == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const _ResultsSkeleton();
        }

        if (snapshot.hasError) {
          return _CenterMessage(
            icon: Icons.wifi_off_rounded,
            message: l10n.connectionErrorMessage,
            actionLabel: l10n.retry,
            onAction: _refresh,
          );
        }

        final data = snapshot.data!;
        final showMerchants =
            _typeFilter == _ResultType.all ||
            _typeFilter == _ResultType.merchants;
        final showProducts =
            _typeFilter == _ResultType.all ||
            _typeFilter == _ResultType.products;
        final showCategories =
            _typeFilter == _ResultType.all ||
            _typeFilter == _ResultType.categories;

        final merchants = showMerchants ? data.merchants : const <Merchant>[];
        var products = showProducts
            ? data.products
            : const <ProductSearchResult>[];
        final categories = showCategories
            ? data.categories
            : const <MerchantCategory>[];

        if (products.isNotEmpty && _sort != _SortOption.relevance) {
          products = [...products]
            ..sort((a, b) {
              final priceA = a.product.price;
              final priceB = b.product.price;
              return _sort == _SortOption.priceLowToHigh
                  ? priceA.compareTo(priceB)
                  : priceB.compareTo(priceA);
            });
        }

        final hasAnyResults =
            merchants.isNotEmpty ||
            products.isNotEmpty ||
            categories.isNotEmpty;

        return Column(
          children: [
            _FilterBar(
              typeFilter: _typeFilter,
              onTypeChanged: (value) => setState(() => _typeFilter = value),
              showSort:
                  _typeFilter == _ResultType.products ||
                  (_typeFilter == _ResultType.all && data.products.isNotEmpty),
              sort: _sort,
              onSortChanged: (value) => setState(() => _sort = value),
              l10n: l10n,
            ),
            Expanded(
              child: !hasAnyResults
                  ? _CenterMessage(
                      icon: Icons.search_off_rounded,
                      message: l10n.noResultsFor(_query),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      children: [
                        if (categories.isNotEmpty) ...[
                          _SectionTitle(l10n.categoriesLabel),
                          for (final category in categories)
                            _CategoryResultTile(
                              category: category,
                              onTap: () => _openCategory(category),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (merchants.isNotEmpty) ...[
                          _SectionTitle(l10n.merchantsLabel),
                          for (final merchant in merchants) ...[
                            MerchantCard(
                              merchant: merchant,
                              onTap: () => _openMerchant(merchant),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (products.isNotEmpty) ...[
                          _SectionTitle(l10n.productsLabel),
                          for (final result in products)
                            _ProductResultTile(
                              result: result,
                              onTap: () => _openProduct(result),
                            ),
                          if (showProducts && data.hasMoreProducts) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _LoadMoreControl(
                              isLoading: _isLoadingMoreProducts,
                              hasError: _loadMoreProductsError,
                              onTap: _loadMoreProducts,
                              l10n: l10n,
                            ),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchResults {
  final List<Merchant> merchants;
  final List<MerchantCategory> categories;
  // غير final عمدًا: _loadMoreProducts يُلحِق بها صفحات إضافية في
  // مكانها (نفس كائن الـFuture المُخزَّن)، بدل إعادة بناء _SearchResults
  // كاملة لمجرد تحميل صفحة واحدة إضافية.
  final List<ProductSearchResult> products;
  bool hasMoreProducts;

  _SearchResults({
    required this.merchants,
    required this.categories,
    required this.products,
    required this.hasMoreProducts,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final IconData? icon;

  const _SearchChip({
    required this.label,
    required this.onTap,
    this.onDismiss,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xlAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: AppRadius.xlAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.history_rounded,
              size: 16,
              color: theme.colorScheme.muted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label),
            if (onDismiss != null) ...[
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: onDismiss,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: theme.colorScheme.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _ResultType typeFilter;
  final ValueChanged<_ResultType> onTypeChanged;
  final bool showSort;
  final _SortOption sort;
  final ValueChanged<_SortOption> onSortChanged;
  final AppLocalizations l10n;

  const _FilterBar({
    required this.typeFilter,
    required this.onTypeChanged,
    required this.showSort,
    required this.sort,
    required this.onSortChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        children: [
          _FilterChoiceChip(
            label: l10n.allLabel,
            selected: typeFilter == _ResultType.all,
            onTap: () => onTypeChanged(_ResultType.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChoiceChip(
            label: l10n.merchantsLabel,
            selected: typeFilter == _ResultType.merchants,
            onTap: () => onTypeChanged(_ResultType.merchants),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChoiceChip(
            label: l10n.productsLabel,
            selected: typeFilter == _ResultType.products,
            onTap: () => onTypeChanged(_ResultType.products),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChoiceChip(
            label: l10n.categoriesLabel,
            selected: typeFilter == _ResultType.categories,
            onTap: () => onTypeChanged(_ResultType.categories),
          ),
          if (showSort) ...[
            const SizedBox(width: AppSpacing.md),
            VerticalDivider(width: 1, indent: 8, endIndent: 8),
            const SizedBox(width: AppSpacing.md),
            PopupMenuButton<_SortOption>(
              initialValue: sort,
              onSelected: onSortChanged,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _SortOption.relevance,
                  child: Text(l10n.sortRelevance),
                ),
                PopupMenuItem(
                  value: _SortOption.priceLowToHigh,
                  child: Text(l10n.sortPriceLowToHigh),
                ),
                PopupMenuItem(
                  value: _SortOption.priceHighToLow,
                  child: Text(l10n.sortPriceHighToLow),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text(l10n.sortLabel),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xlAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: AppRadius.xlAll,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CategoryResultTile extends StatelessWidget {
  final MerchantCategory category;
  final VoidCallback onTap;

  const _CategoryResultTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = MerchantCategoryIcon.colorFor(category.id);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.smAll,
          ),
          child: Icon(MerchantCategoryIcon.iconFor(category), color: color),
        ),
        title: Text(
          category.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }
}

class _ProductResultTile extends StatelessWidget {
  final ProductSearchResult result;
  final VoidCallback onTap;

  const _ProductResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = result.product;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: AppRadius.smAll,
          child: product.imageUrl != null
              ? Hero(
                  tag: 'product-image-${product.id}',
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    memCacheWidth: 144,
                    memCacheHeight: 144,
                    placeholder: (context, url) => Container(
                      width: 48,
                      height: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 48,
                      height: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
        ),
        title: Text(
          product.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(result.merchantName),
        trailing: Text(
          AppLocalizations.of(context)
              .currencyAmount(product.price.toStringAsFixed(0)),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// عنصر "تحميل المزيد" أسفل قائمة المنتجات — 3 حالات: زر عادي، مؤشر
/// تحميل أثناء جلب الصفحة التالية، أو رسالة خطأ + إعادة محاولة عند
/// فشل الصفحة الإضافية تحديدًا (لا يؤثر على النتائج المحمَّلة أصلًا).
class _LoadMoreControl extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _LoadMoreControl({
    required this.isLoading,
    required this.hasError,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Column(
            children: [
              Text(
                l10n.loadMoreError,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(onPressed: onTap, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(l10n.loadMoreAction),
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenterMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.muted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.muted,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton بسيط أثناء انتظار نتائج البحث — بديل عن مؤشر تحميل وحيد،
/// نفس فلسفة _HomeLoadingSkeleton في home_screen.dart.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => Container(
        height: 72,
        decoration: BoxDecoration(color: base, borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
