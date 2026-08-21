import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/advertisement.dart';
import '../models/home_section.dart';
import '../models/merchant.dart';
import '../models/merchant_category.dart';
import '../services/branding_service.dart';
import '../services/location_service.dart';
import '../utils/merchant_category_icon.dart';
import '../utils/nearest_merchants.dart';
import '../widgets/ad_carousel.dart';
import '../widgets/app_logo.dart';
import '../widgets/category_chip.dart';
import '../widgets/merchant_smart_section.dart';
import 'account_screen.dart';
import 'all_categories_screen.dart';
import 'merchant_products_screen.dart';
import 'merchants_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';

/// الصفحة الرئيسية الفعلية للتطبيق — Feed ديناميكي متعدد الأقسام، تحلّ
/// محل الشبكة الثابتة القديمة (كانت MerchantCategoriesScreen هي نقطة
/// الدخول، تعرض شبكة تصنيفات فقط + إعلانات أعلاها). كل قسم من أقسام هذه
/// الصفحة (hero/categories/featured/nearby/newest/most_ordered) يظهر
/// بترتيب وعنوان تتحكّم بهما لوحة الإدارة بالكامل (جدول home_sections)،
/// ويختفي تلقائيًا إن لم توجد له بيانات حقيقية كافية — لا نعرض أبدًا
/// قسمًا فارغًا أو "قريبًا" مكرَّرة (راجع تعليق _buildSection أدناه).
///
/// كتالوج الأقسام مقصود أنه محدود (وليس منشئ صفحات حر) — راجع تعليق
/// migration 20260821060000_home_sections.sql للتفسير الكامل. أقسام
/// طلبها المستخدم صراحةً استُبعدت هنا لعدم وجود نموذج بيانات حقيقي
/// يدعمها بعد (بدل تلفيق بيانات وهمية): "أفضل العروض" (لا جدول خصومات)،
/// "الأكثر مشاهدة" (لا تتبّع مشاهدات على المحلات)، "مقترح لك" (لا محرّك
/// توصية حقيقي). عند إضافة تلك النماذج لاحقًا، تُضاف كأنواع section_key
/// جديدة بنفس النمط بالضبط.
class HomeScreen extends StatefulWidget {
  final String locationName;

  const HomeScreen({super.key, required this.locationName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _dataFuture;
  Position? _devicePosition;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchHomeData();

    // مستقل تمامًا عن تحميل بقية الصفحة — لا ننتظره، ولا يظهر أي مؤشر
    // تحميل أو خطأ خاص به. إن تأخّر أو رفض المستخدم الإذن، تبقى الصفحة
    // تعمل بشكل طبيعي بدون قسم "بالقرب منك" فقط (نفس فلسفة MerchantsScreen).
    LocationService.getCurrentPosition().then((position) {
      if (mounted && position != null) {
        setState(() => _devicePosition = position);
      }
    });
  }

  Future<_HomeData> _fetchHomeData() async {
    final client = Supabase.instance.client;
    const merchantColumns =
        'id, store_name, phone, communes(name), latitude, longitude, '
        'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

    final sectionsFuture = client
        .from('home_sections')
        .select('id, section_key, title, sort_order')
        .order('sort_order', ascending: true);

    final categoriesFuture = client
        .from('merchant_categories')
        .select('id, name, icon')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    // عدد المحلات لكل تصنيف يُحسب محليًا (نفس منطق AllCategoriesScreen).
    final categoryCountsFuture = client
        .from('merchants')
        .select('category_id')
        .eq('status', 'approved');

    final adsFuture = client
        .from('advertisements')
        .select(
          'id, title, description, advertiser_name, video_url, '
          'thumbnail_url, link_url, start_date, end_date',
        )
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final featuredFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .eq('is_featured', true)
        .order('store_name')
        .limit(10);

    final newestFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(10);

    final topOrderedFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .gt('orders_count', 0)
        .order('orders_count', ascending: false)
        .limit(10);

    // مجمّع مرشَّحين لقسم "بالقرب منك": كل محل حفظ موقعه الجغرافي، غير
    // مرتَّب بعد بالمسافة (يُرتَّب محليًا بمجرّد توفّر موقع الجهاز — راجع
    // nearestMerchants). سقف 60 محلًا كافٍ جدًا لحجم بيانات خنشلة الحالي
    // (نفس منطق "حساب على الجهاز عند هذا الحجم من البيانات" المتّبع في
    // بقية الشاشات)، ويمنع جلب كل جدول المحلات لمجرّد إيجاد الأقرب.
    final nearbyPoolFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .not('latitude', 'is', null)
        .limit(60);

    final results = await Future.wait([
      sectionsFuture,
      categoriesFuture,
      categoryCountsFuture,
      adsFuture,
      featuredFuture,
      newestFuture,
      topOrderedFuture,
      nearbyPoolFuture,
    ]);

    final sections = (results[0] as List)
        .map((row) => HomeSection.fromMap(row as Map<String, dynamic>))
        .where((section) => section.key != HomeSectionKey.unknown)
        .toList();

    final counts = <String, int>{};
    for (final row in results[2] as List) {
      final categoryId = row['category_id'] as String?;
      if (categoryId == null) continue;
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }

    final ads = (results[3] as List)
        .map((row) => Advertisement.fromMap(row as Map<String, dynamic>))
        .where((ad) => ad.isCurrentlyActive)
        .toList();

    return _HomeData(
      sections: sections,
      ads: ads,
      categories: (results[1] as List)
          .map((row) => MerchantCategory.fromMap(row as Map<String, dynamic>))
          .toList(),
      categoryCounts: counts,
      featured: _toMerchants(results[4]),
      newest: _toMerchants(results[5]),
      topOrdered: _toMerchants(results[6]),
      nearbyPool: _toMerchants(results[7]),
    );
  }

  List<Merchant> _toMerchants(List<dynamic> rows) {
    return rows
        .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refresh() => setState(() => _dataFuture = _fetchHomeData());

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
          locationName: widget.locationName,
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
  }

  void _openAllCategories() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllCategoriesScreen(locationName: widget.locationName),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            AppLogo(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                BrandingService.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'إشعاراتي',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'حسابي',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: FutureBuilder<_HomeData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _HomeLoadingSkeleton();
            }

            if (snapshot.hasError) {
              return _StateMessage(
                icon: Icons.wifi_off_rounded,
                message:
                    'تعذّر تحميل الصفحة الرئيسية. تحقق من اتصالك بالإنترنت.',
                actionLabel: 'إعادة المحاولة',
                onAction: _refresh,
              );
            }

            final data = snapshot.data!;
            final nearby = nearestMerchants(data.nearbyPool, _devicePosition);

            final sectionWidgets = <Widget>[];
            for (final section in data.sections) {
              final widget = _buildSection(section, data, nearby);
              if (widget != null) sectionWidgets.add(widget);
            }

            // حالة فارغة حقيقية واحدة ومميَّزة (لا "قريبًا" مكرَّرة على كل
            // قسم) — تظهر فقط إذا لم يوجد أي محتوى حقيقي إطلاقًا في كل
            // أقسام الصفحة معًا.
            if (sectionWidgets.isEmpty) {
              return _StateMessage(
                icon: Icons.storefront_outlined,
                message:
                    'المحتوى قيد الإعداد حاليًا في ${widget.locationName}.\nعد قريبًا!',
                actionLabel: 'إعادة المحاولة',
                onAction: _refresh,
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: _HomeSearchBar(onTap: _openSearch),
                    ),
                  ),
                  SliverList.list(children: sectionWidgets),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// يبني Widget قسم واحد، أو null إن لم توجد له بيانات حقيقية كافية —
  /// المستدعي (build أعلاه) يتجاهل النتيجة null بالكامل، فلا يظهر أي أثر
  /// للقسم على الصفحة (لا عنوان فارغ، لا "قريبًا"). هذا هو التطبيق العملي
  /// لقاعدة "القسم يُخفى تلقائيًا حتى لو كان مفعَّلًا من الإدارة" الموثّقة
  /// في migration home_sections.
  Widget? _buildSection(
    HomeSection section,
    _HomeData data,
    List<Merchant> nearby,
  ) {
    switch (section.key) {
      case HomeSectionKey.hero:
        if (data.ads.isEmpty) return null;
        return AdCarousel(ads: data.ads);

      case HomeSectionKey.categories:
        if (data.categories.isEmpty) return null;
        return _CategoriesSection(
          title: section.title,
          categories: data.categories,
          counts: data.categoryCounts,
          onTapCategory: _openCategory,
          onSeeAll: _openAllCategories,
        );

      case HomeSectionKey.featured:
        if (data.featured.isEmpty) return null;
        return MerchantSmartSection(
          title: section.title,
          icon: Icons.star_rounded,
          merchants: data.featured,
          onTapMerchant: _openMerchant,
        );

      case HomeSectionKey.nearby:
        if (nearby.isEmpty) return null;
        return MerchantSmartSection(
          title: section.title,
          icon: Icons.near_me_rounded,
          merchants: nearby,
          onTapMerchant: _openMerchant,
        );

      case HomeSectionKey.newest:
        if (data.newest.isEmpty) return null;
        return MerchantSmartSection(
          title: section.title,
          icon: Icons.fiber_new_rounded,
          merchants: data.newest,
          onTapMerchant: _openMerchant,
        );

      case HomeSectionKey.mostOrdered:
        if (data.topOrdered.isEmpty) return null;
        return MerchantSmartSection(
          title: section.title,
          icon: Icons.local_fire_department_rounded,
          merchants: data.topOrdered,
          onTapMerchant: _openMerchant,
        );

      case HomeSectionKey.unknown:
        return null;
    }
  }
}

/// حزمة بيانات الصفحة الرئيسية الكاملة — كل قسم مصدر بياناته مستقل تمامًا
/// (لا نعرض قسمًا بلا بيانات حقيقية، راجع _buildSection).
class _HomeData {
  final List<HomeSection> sections;
  final List<Advertisement> ads;
  final List<MerchantCategory> categories;
  final Map<String, int> categoryCounts;
  final List<Merchant> featured;
  final List<Merchant> newest;
  final List<Merchant> topOrdered;
  final List<Merchant> nearbyPool;

  const _HomeData({
    required this.sections,
    required this.ads,
    required this.categories,
    required this.categoryCounts,
    required this.featured,
    required this.newest,
    required this.topOrdered,
    required this.nearbyPool,
  });
}

/// شريط بحث "زخرفي" أعلى الصفحة الرئيسية — لا يحرّر النص هنا مباشرة، بل
/// ينقل فورًا إلى SearchScreen (نفس نمط تطبيقات التجارة الكبرى: شريط
/// البحث الرئيسي واجهة تنقّل لا حقل تحرير مستقل). RTL كامل تلقائيًا من
/// اتجاه التطبيق العام (Locale('ar'))، فلا حاجة لأي عكس يدوي هنا.
class _HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Text(
                'ابحث عن محل أو تصنيف...',
                style: theme.textTheme.bodyMedium?.copyWith(
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

/// قسم التصنيفات المختصر في الصفحة الرئيسية: شرائح أفقية محدودة العدد
/// (بدل شبكة كبيرة ثابتة كما كانت الصفحة الرئيسية القديمة) + شريحة
/// "عرض الكل" تفتح AllCategoriesScreen لعرض كل التصنيفات في شبكة كاملة.
class _CategoriesSection extends StatelessWidget {
  static const int _visibleCount = 8;

  final String title;
  final List<MerchantCategory> categories;
  final Map<String, int> counts;
  final ValueChanged<MerchantCategory> onTapCategory;
  final VoidCallback onSeeAll;

  const _CategoriesSection({
    required this.title,
    required this.categories,
    required this.counts,
    required this.onTapCategory,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = categories.take(_visibleCount).toList();
    final hasMore = categories.length > _visibleCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onSeeAll, child: const Text('عرض الكل')),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: visible.length + (hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  return SeeAllCategoriesChip(onTap: onSeeAll);
                }
                final category = visible[index];
                return CategoryChip(
                  icon: MerchantCategoryIcon.iconFor(category),
                  color: MerchantCategoryIcon.colorFor(category.id),
                  label: category.name,
                  onTap: () => onTapCategory(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة موحَّدة لعرض رسالة في منتصف الشاشة: فارغة أو خطأ.
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

/// عرض Skeleton بسيط أثناء أول تحميل — يعكس شكل الصفحة القادمة تقريبًا
/// (شريط بحث + بانر + صف شرائح + بطاقات أفقية) بدل مؤشر تحميل وحيد.
class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    Widget block({required double height, EdgeInsets? margin}) => Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        block(height: 52),
        const SizedBox(height: 16),
        block(height: 180),
        const SizedBox(height: 20),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: 76,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => Container(
              width: 128,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
