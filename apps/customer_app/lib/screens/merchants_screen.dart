import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant.dart';
import '../services/location_service.dart';
import '../utils/nearest_merchants.dart';
import '../widgets/merchant_card.dart';
import '../widgets/merchant_smart_section.dart';
import '../widgets/search_field.dart';
import 'account_screen.dart';
import 'merchant_products_screen.dart';

/// شاشة قائمة المحلات — تُفتح من HomeScreen أو AllCategoriesScreen، إما
/// لتصنيف محدَّد (categoryId) أو لكل المحلات (categoryId = null، بطاقة
/// "كل المحلات"). تجلب فقط المحلات الموافَق عليها من طرف Admin
/// (status = approved)، نفس القاعدة المطبَّقة في RLS على جدول merchants.
///
/// عند فتحها لتصنيف محدَّد، تُضاف فوق القائمة الكاملة أقسام ذكية أفقية
/// (مميزة / الأكثر طلبًا / مفتوح الآن / الأقرب إليك / المضافة حديثًا)
/// — كل قسم يظهر فقط إن كانت له بيانات حقيقية (لا نعرض قسمًا فارغًا أو
/// وهميًا). "مفتوح الآن" و"الأقرب إليك" يُحسبان محليًا في الجهاز (لا
/// استعلام إضافي للخادم) — الأول من ساعات العمل (MerchantOpenStatus)،
/// والثاني من موقع الجهاز الحالي (LocationService) مقابل إحداثيات كل
/// محل (haversineKm، عبر nearest_merchants.dart المشترك مع HomeScreen).
/// طلب إذن الموقع لا يُعطّل تحميل بقية الشاشة أبدًا — يجري بالتوازي،
/// وقسم "الأقرب إليك" يظهر لاحقًا فور توفّره فقط.
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
  Position? _devicePosition;

  @override
  void initState() {
    super.initState();
    _pageFuture = _fetchPageData();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });

    // مستقل تمامًا عن تحميل قائمة المحلات — لا ننتظره، ولا يظهر أي
    // مؤشر تحميل أو خطأ خاص به. إن تأخّر أو رفض المستخدم الإذن، تبقى
    // الشاشة تعمل بشكل طبيعي بدون قسم "الأقرب إليك" فقط.
    if (widget.categoryId != null) {
      LocationService.getCurrentPosition().then((position) {
        if (mounted && position != null) {
          setState(() => _devicePosition = position);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_MerchantsPageData> _fetchPageData() async {
    final client = Supabase.instance.client;
    const columns =
        'id, store_name, phone, communes(name), latitude, longitude, '
        'logo_url, cover_url, '
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
      // التصنيفات (AllCategoriesScreen)، لأن بطاقات هذه الشاشة (الأفقية
      // والعمودية) لها ارتفاعات محسوبة مسبقًا أيضًا.
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
            final nearest = nearestMerchants(page.all, _devicePosition);
            final showSections =
                _query.isEmpty &&
                (page.featured.isNotEmpty ||
                    page.topOrdered.isNotEmpty ||
                    page.openNow.isNotEmpty ||
                    nearest.isNotEmpty ||
                    page.newest.isNotEmpty);

            void openMerchant(Merchant merchant) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MerchantProductsScreen(
                    merchantId: merchant.id,
                    storeName: merchant.storeName,
                    logoUrl: merchant.logoUrl,
                    coverUrl: merchant.coverUrl,
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: SearchField(controller: _searchController),
                  ),
                ),
                if (showSections)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (page.featured.isNotEmpty)
                          MerchantSmartSection(
                            title: 'مميزة',
                            icon: Icons.star_rounded,
                            merchants: page.featured,
                            onTapMerchant: openMerchant,
                          ),
                        if (page.topOrdered.isNotEmpty)
                          MerchantSmartSection(
                            title: 'الأكثر طلبًا',
                            icon: Icons.local_fire_department_rounded,
                            merchants: page.topOrdered,
                            onTapMerchant: openMerchant,
                          ),
                        if (page.openNow.isNotEmpty)
                          MerchantSmartSection(
                            title: 'مفتوح الآن',
                            icon: Icons.access_time_filled_rounded,
                            merchants: page.openNow,
                            onTapMerchant: openMerchant,
                          ),
                        if (nearest.isNotEmpty)
                          MerchantSmartSection(
                            title: 'الأقرب إليك',
                            icon: Icons.near_me_rounded,
                            merchants: nearest,
                            onTapMerchant: openMerchant,
                          ),
                        if (page.newest.isNotEmpty)
                          MerchantSmartSection(
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
                        return MerchantCard(
                          merchant: merchant,
                          distanceLabel: distanceLabelFor(
                            merchant,
                            _devicePosition,
                          ),
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
