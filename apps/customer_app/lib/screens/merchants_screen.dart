import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant.dart';
import '../widgets/merchant_mini_card.dart';
import '../widgets/open_status_badge.dart';
import 'account_screen.dart';
import 'merchant_products_screen.dart';

/// شاشة قائمة المحلات — تُفتح دائمًا من MerchantCategoriesScreen، إما
/// لتصنيف محدَّد (categoryId) أو لكل المحلات (categoryId = null، بطاقة
/// "كل المحلات"). تجلب فقط المحلات الموافَق عليها من طرف Admin
/// (status = approved)، نفس القاعدة المطبَّقة في RLS على جدول merchants.
///
/// عند فتحها لتصنيف محدَّد، تُضاف فوق القائمة الكاملة أقسام ذكية أفقية
/// (مميزة / الأكثر طلبًا / مفتوح الآن / المضافة حديثًا) — كل قسم يظهر
/// فقط إن كانت له بيانات حقيقية (لا نعرض قسمًا فارغًا أو وهميًا).
/// "مفتوح الآن" يُحسب محليًا في الجهاز من ساعات العمل التي يحفظها
/// التاجر (راجع MerchantOpenStatus) — لا استعلام إضافي للخادم، لأنه
/// مُشتق من نفس قائمة "كل المحلات" المجلوبة أصلًا. قسم "الأقرب إليك"
/// غير موجود عمدًا: لا بيانات موقع جغرافي بعد — قرار Phase مؤجَّل.
class MerchantsScreen extends StatefulWidget {
  final String locationName;
  final String? categoryId;
  final String? categoryName;

  const MerchantsScreen({
    super.key,
    required this.locationName,
    this.categoryId,
    this.categoryName,
  });

  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen> {
  late Future<_MerchantsPageData> _pageFuture;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _pageFuture = _fetchPageData();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_MerchantsPageData> _fetchPageData() async {
    final client = Supabase.instance.client;
    const columns =
        'id, store_name, phone, communes(name), '
        'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

    var allQuery = client
        .from('merchants')
        .select(columns)
        .eq('status', 'approved');
    if (widget.categoryId != null) {
      allQuery = allQuery.eq('category_id', widget.categoryId!);
    }
    final allFuture = allQuery.order('store_name');

    // الأقسام الذكية معنى لها فقط داخل تصنيف محدَّد — عرضها فوق "كل
    // المحلات" (بدون فلتر) سيكرّر نفس المحتوى بلا فائدة إضافية.
    if (widget.categoryId == null) {
      final all = _toMerchants(await allFuture);
      return _MerchantsPageData(
        all: all,
        featured: [],
        topOrdered: [],
        newest: [],
        openNow: [],
      );
    }

    final featuredFuture = client
        .from('merchants')
        .select(columns)
        .eq('status', 'approved')
        .eq('category_id', widget.categoryId!)
        .eq('is_featured', true)
        .order('store_name')
        .limit(8);

    final topOrderedFuture = client
        .from('merchants')
        .select(columns)
        .eq('status', 'approved')
        .eq('category_id', widget.categoryId!)
        .gt('orders_count', 0)
        .order('orders_count', ascending: false)
        .limit(8);

    final newestFuture = client
        .from('merchants')
        .select(columns)
        .eq('status', 'approved')
        .eq('category_id', widget.categoryId!)
        .order('created_at', ascending: false)
        .limit(8);

    final results = await Future.wait([
      allFuture,
      featuredFuture,
      topOrderedFuture,
      newestFuture,
    ]);

    final all = _toMerchants(results[0]);

    return _MerchantsPageData(
      all: all,
      featured: _toMerchants(results[1]),
      topOrdered: _toMerchants(results[2]),
      // "المضافة حديثًا" لا تُظهر شيئًا مميّزًا في تصنيف صغير (كل المحلات
      // فيه أصلًا حديثة) — نعرضها فقط إن كان في التصنيف أكثر من 4 محلات.
      newest: all.length > 4 ? _toMerchants(results[3]) : [],
      // يُحسب محليًا من نفس القائمة الكاملة (لا استعلام إضافي) — راجع
      // تعليق الشاشة أعلاه.
      openNow: all.where((m) => m.isOpenNow == true).take(8).toList(),
    );
  }

  List<Merchant> _toMerchants(List<dynamic> rows) {
    return rows
        .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  List<Merchant> _filter(List<Merchant> merchants) {
    if (_query.isEmpty) return merchants;
    final q = _query.toLowerCase();
    return merchants
        .where((m) => m.storeName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName != null
              ? '${widget.categoryName} في ${widget.locationName}'
              : 'كل المحلات في ${widget.locationName}',
        ),
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
      // سقف أعلى لتكبير خط النظام — نفس إصلاح Overflow المطبَّق في شبكة
      // التصنيفات (MerchantCategoriesScreen)، لأن بطاقات هذه الشاشة
      // (الأفقية والعمودية) لها ارتفاعات محسوبة مسبقًا أيضًا.
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: FutureBuilder<_MerchantsPageData>(
          future: _pageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _MerchantsLoadingSkeleton();
            }

            if (snapshot.hasError) {
              return _StateMessage(
                icon: Icons.wifi_off_rounded,
                message: 'تعذّر تحميل قائمة المحلات. تحقق من اتصالك بالإنترنت.',
                actionLabel: 'إعادة المحاولة',
                onAction: () {
                  setState(() {
                    _pageFuture = _fetchPageData();
                  });
                },
              );
            }

            final page = snapshot.data!;

            if (page.all.isEmpty) {
              return const _StateMessage(
                icon: Icons.storefront_outlined,
                message: 'لا توجد محلات متاحة حاليًا. عد قريبًا!',
              );
            }

            final merchants = _filter(page.all);
            final showSections =
                _query.isEmpty &&
                (page.featured.isNotEmpty ||
                    page.topOrdered.isNotEmpty ||
                    page.openNow.isNotEmpty ||
                    page.newest.isNotEmpty);

            void openMerchant(Merchant merchant) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MerchantProductsScreen(
                    merchantId: merchant.id,
                    storeName: merchant.storeName,
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _SearchField(controller: _searchController),
                  ),
                ),
                if (showSections)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (page.featured.isNotEmpty)
                          _SmartSection(
                            title: 'مميزة',
                            icon: Icons.star_rounded,
                            merchants: page.featured,
                            onTapMerchant: openMerchant,
                          ),
                        if (page.topOrdered.isNotEmpty)
                          _SmartSection(
                            title: 'الأكثر طلبًا',
                            icon: Icons.local_fire_department_rounded,
                            merchants: page.topOrdered,
                            onTapMerchant: openMerchant,
                          ),
                        if (page.openNow.isNotEmpty)
                          _SmartSection(
                            title: 'مفتوح الآن',
                            icon: Icons.access_time_filled_rounded,
                            merchants: page.openNow,
                            onTapMerchant: openMerchant,
                          ),
                        if (page.newest.isNotEmpty)
                          _SmartSection(
                            title: 'أُضيفت حديثًا',
                            icon: Icons.fiber_new_rounded,
                            merchants: page.newest,
                            onTapMerchant: openMerchant,
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'كل المحلات',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (merchants.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _StateMessage(
                      icon: Icons.search_off_rounded,
                      message: 'لا توجد نتائج لـ "$_query"',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: merchants.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final merchant = merchants[index];
                        return _MerchantCard(
                          merchant: merchant,
                          onTap: () => openMerchant(merchant),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// حزمة بيانات صفحة المحلات: القائمة الكاملة + الأقسام الذكية الأربعة
/// (تبقى فارغة تلقائيًا عند فتح الشاشة بدون تصنيف محدَّد، أو حين لا
/// توجد بيانات حقيقية كافية لأي قسم — لا نعرض قسمًا فارغًا أبدًا).
class _MerchantsPageData {
  final List<Merchant> all;
  final List<Merchant> featured;
  final List<Merchant> topOrdered;
  final List<Merchant> openNow;
  final List<Merchant> newest;

  const _MerchantsPageData({
    required this.all,
    required this.featured,
    required this.topOrdered,
    required this.openNow,
    required this.newest,
  });
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث عن محل...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clear,
                ),
        ),
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;

  const _MerchantCard({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (merchant.communeName != null ||
                        merchant.isOpenNow != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (merchant.communeName != null) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              merchant.communeName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                          if (merchant.communeName != null &&
                              merchant.isOpenNow != null)
                            const SizedBox(width: 8),
                          if (merchant.isOpenNow != null)
                            OpenStatusBadge(isOpen: merchant.isOpenNow!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قسم أفقي قابل للتمرير (مميزة / الأكثر طلبًا / مفتوح الآن / المضافة
/// حديثًا) — يظهر فقط عبر الاستدعاء الشرطي في build()، لا يعرض نفسه
/// فارغًا أبدًا.
class _SmartSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Merchant> merchants;
  final ValueChanged<Merchant> onTapMerchant;

  const _SmartSection({
    required this.title,
    required this.icon,
    required this.merchants,
    required this.onTapMerchant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: merchants.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return MerchantMiniCard(
                  merchant: merchant,
                  onTap: () => onTapMerchant(merchant),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة موحَّدة لعرض رسالة في منتصف الشاشة: فارغة، خطأ، أو بحث بلا نتائج.
class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
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
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// عرض Skeleton بسيط بدل مؤشر تحميل دائري وحيد — يعطي إحساسًا فوريًا
/// بشكل الصفحة القادمة بدل شاشة فارغة أثناء التحميل.
class _MerchantsLoadingSkeleton extends StatelessWidget {
  const _MerchantsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        height: 84,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
