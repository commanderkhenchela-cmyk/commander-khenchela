import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant_category.dart';
import 'account_screen.dart';
import 'merchants_screen.dart';

/// شاشة الدخول الرئيسية بعد تأكيد الولاية — تعرض شبكة تصنيفات المحلات
/// (مطاعم، بقالة، صيدليات...) أولًا، قبل أي قائمة محلات، حسب طلب صريح:
/// "الصفحة الرئيسية يجب أن تعرض تصنيفات المحلات أولاً... وليس قائمة
/// مباشرة بكل المحلات". التصنيفات ديناميكية بالكامل من جدول
/// merchant_categories (لوحة الإدارة تتحكم بها) — لا شيء هنا Hardcoded.
class MerchantCategoriesScreen extends StatefulWidget {
  final String locationName;

  const MerchantCategoriesScreen({super.key, required this.locationName});

  @override
  State<MerchantCategoriesScreen> createState() =>
      _MerchantCategoriesScreenState();
}

class _MerchantCategoriesScreenState extends State<MerchantCategoriesScreen> {
  late Future<_CategoriesData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<_CategoriesData> _fetchData() async {
    final client = Supabase.instance.client;

    final categoriesData = await client
        .from('merchant_categories')
        .select('id, name, icon')
        .eq('is_active', true)
        .order('sort_order');

    // عدد المحلات لكل تصنيف يُحسب هنا محليًا من قائمة المحلات الموافَق
    // عليها فقط — لا حاجة لدالة group by في قاعدة البيانات عند هذا الحجم
    // من البيانات (نفس منطق البحث الآني المستخدَم في MerchantsScreen).
    final merchantsData = await client
        .from('merchants')
        .select('category_id')
        .eq('status', 'approved');

    final counts = <String, int>{};
    for (final row in merchantsData as List) {
      final categoryId = (row as Map<String, dynamic>)['category_id'] as String?;
      if (categoryId == null) continue;
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }

    final categories = (categoriesData as List)
        .map((row) => MerchantCategory.fromMap(row as Map<String, dynamic>))
        .toList();

    return _CategoriesData(
      categories: categories,
      counts: counts,
      totalMerchants: (merchantsData).length,
    );
  }

  void _refresh() => setState(() => _dataFuture = _fetchData());

  void _openMerchants({String? categoryId, String? categoryName}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantsScreen(
          locationName: widget.locationName,
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المحلات في ${widget.locationName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'حسابي',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
          ),
        ],
      ),
      body: FutureBuilder<_CategoriesData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final data = snapshot.data!;

          if (data.categories.isEmpty) {
            return const _ErrorState(
              message: 'لا توجد تصنيفات متاحة حاليًا. عد قريبًا!',
              icon: Icons.category_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: data.categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryTile(
                    icon: '🏬',
                    label: 'كل المحلات',
                    count: data.totalMerchants,
                    onTap: () => _openMerchants(),
                  );
                }
                final category = data.categories[index - 1];
                return _CategoryTile(
                  icon: category.icon,
                  label: category.name,
                  count: data.counts[category.id] ?? 0,
                  onTap: () => _openMerchants(
                    categoryId: category.id,
                    categoryName: category.name,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoriesData {
  final List<MerchantCategory> categories;
  final Map<String, int> counts;
  final int totalMerchants;

  const _CategoriesData({
    required this.categories,
    required this.counts,
    required this.totalMerchants,
  });
}

class _CategoryTile extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count محل',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback? onRetry;
  final String message;
  final IconData icon;

  const _ErrorState({
    this.onRetry,
    this.message = 'تعذّر تحميل التصنيفات. تحقق من اتصالك بالإنترنت.',
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.black45),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
