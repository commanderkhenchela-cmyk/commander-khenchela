import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant.dart';
import '../models/merchant_category.dart';
import '../utils/merchant_category_icon.dart';
import '../widgets/merchant_card.dart';
import '../widgets/search_field.dart';
import 'merchant_products_screen.dart';
import 'merchants_screen.dart';

/// شاشة البحث العامة — تُفتح من شريط البحث في الصفحة الرئيسية. تبحث في
/// نطاقين حقيقيين موجودين فعلًا: أسماء المحلات، وأسماء تصنيفات المحلات
/// (لا نلفّق نطاق بحث "منتجات/خدمات" شامل عبر كل المحلات — يحتاج فهرس
/// بحث مخصَّص لا يوجد بعد؛ بحث المنتجات الحالي متاح داخل صفحة كل محل على
/// حدة كما هو). القائمتان (المحلات المعتمدة + التصنيفات النشطة) تُحمَّلان
/// مرة واحدة عند فتح الشاشة، والفلترة تجري محليًا فورًا مع كل حرف —
/// نفس أسلوب البحث الفوري المستخدَم في MerchantsScreen.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  late Future<_SearchPool> _poolFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _poolFuture = _loadPool();
    _controller.addListener(() {
      setState(() => _query = _controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_SearchPool> _loadPool() async {
    final client = Supabase.instance.client;
    const merchantColumns =
        'id, store_name, phone, communes(name), latitude, longitude, '
        'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

    final merchantsFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .order('store_name');

    final categoriesFuture = client
        .from('merchant_categories')
        .select('id, name, icon')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final results = await Future.wait([merchantsFuture, categoriesFuture]);

    return _SearchPool(
      merchants: (results[0] as List)
          .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
          .toList(),
      categories: (results[1] as List)
          .map((row) => MerchantCategory.fromMap(row as Map<String, dynamic>))
          .toList(),
    );
  }

  void _openMerchant(Merchant merchant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantProductsScreen(
          merchantId: merchant.id,
          storeName: merchant.storeName,
        ),
      ),
    );
  }

  void _openCategory(MerchantCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantsScreen(
          locationName: 'خنشلة',
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchField(
          controller: _controller,
          autofocus: true,
          hintText: 'ابحث عن محل أو تصنيف...',
        ),
      ),
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: FutureBuilder<_SearchPool>(
          future: _poolFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _CenterMessage(
                icon: Icons.wifi_off_rounded,
                message: 'تعذّر تحميل نتائج البحث. تحقق من اتصالك بالإنترنت.',
              );
            }

            if (_query.isEmpty) {
              return const _CenterMessage(
                icon: Icons.search_rounded,
                message: 'ابحث عن اسم محل أو تصنيف',
              );
            }

            final pool = snapshot.data!;
            final q = _query.toLowerCase();
            final categories = pool.categories
                .where((c) => c.name.toLowerCase().contains(q))
                .toList();
            final merchants = pool.merchants
                .where((m) => m.storeName.toLowerCase().contains(q))
                .toList();

            if (categories.isEmpty && merchants.isEmpty) {
              return _CenterMessage(
                icon: Icons.search_off_rounded,
                message: 'لا توجد نتائج لـ "$_query"',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (categories.isNotEmpty) ...[
                  Text(
                    'التصنيفات',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final category in categories)
                    _CategoryResultTile(
                      category: category,
                      onTap: () => _openCategory(category),
                    ),
                  const SizedBox(height: 16),
                ],
                if (merchants.isNotEmpty) ...[
                  Text(
                    'المحلات',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final merchant in merchants) ...[
                    MerchantCard(
                      merchant: merchant,
                      onTap: () => _openMerchant(merchant),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchPool {
  final List<Merchant> merchants;
  final List<MerchantCategory> categories;

  const _SearchPool({required this.merchants, required this.categories});
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
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
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

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CenterMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
