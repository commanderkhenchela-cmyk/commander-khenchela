import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/advertisement.dart';
import '../models/home_section.dart';
import '../models/merchant.dart';
import '../models/merchant_category.dart';
import '../models/service.dart';
import '../services/branding_service.dart';
import '../services/location_service.dart';
import '../utils/nearest_merchants.dart';
import '../utils/service_icon.dart';
import '../widgets/ad_carousel.dart';
import '../widgets/app_logo.dart';
import '../widgets/home/home_categories_section.dart';
import '../widgets/home/home_loading_skeleton.dart';
import '../widgets/home/home_search_bar.dart';
import '../widgets/home/home_services_section.dart';
import '../widgets/home/home_state_message.dart';
import '../widgets/merchant_smart_section.dart';
import 'account_screen.dart';
import 'all_categories_screen.dart';
import 'merchant_products_screen.dart';
import 'merchants_screen.dart';
import 'notifications_screen.dart';
import '../features/search/presentation/search_screen.dart';

/// الصفحة الرئيسية الفعلية للتطبيق — Feed ديناميكي متعدد الأقسام، تحلّ
/// محل الشبكة الثابتة القديمة (كانت MerchantCategoriesScreen هي نقطة
/// الدخول، تعرض شبكة تصنيفات فقط + إعلانات أعلاها). كل قسم من أقسام هذه
/// الصفحة (hero/categories/featured/nearby/newest/most_ordered/
/// most_viewed) يظهر بترتيب وعنوان تتحكّم بهما لوحة الإدارة بالكامل
/// (جدول home_sections)، ويختفي تلقائيًا إن لم توجد له بيانات حقيقية
/// كافية — لا نعرض أبدًا قسمًا فارغًا أو "قريبًا" مكرَّرة (راجع تعليق
/// _buildSection أدناه). "الأكثر مشاهدة" مبني على views_count حقيقي
/// (راجع MerchantViewsService وmigration merchant_views) — كان مستبعدًا
/// سابقًا لعدم وجود تتبّع مشاهدات، فبُني التتبّع نفسه بدل تلفيق ترتيب.
///
/// كتالوج الأقسام مقصود أنه محدود (وليس منشئ صفحات حر) — راجع تعليق
/// migration 20260821060000_home_sections.sql للتفسير الكامل. أقسام
/// أخرى طلبها المستخدم صراحةً لا تزال مستبعدة لعدم وجود نموذج بيانات
/// حقيقي يدعمها بعد (بدل تلفيق بيانات وهمية): "أفضل العروض" (لا جدول
/// خصومات)، "مقترح لك" (لا محرّك توصية حقيقي). عند إضافة تلك النماذج
/// لاحقًا، تُضاف كأنواع section_key جديدة بنفس النمط بالضبط.
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
        'logo_url, cover_url, rating_avg, rating_count, is_open, '
        'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

    final sectionsFuture = client
        .from('home_sections')
        .select('id, section_key, title, sort_order')
        .order('sort_order', ascending: true);

    // "الخدمات" ليست قسمًا من home_sections (منطقها مختلف: شبكة تنقّل
    // ثابتة أعلى الصفحة، مو محتوى ديناميكي قابل لإعادة الترتيب مع بقية
    // الأقسام) — راجع migration 20260824000000_services للسياق الكامل.
    final servicesFuture = client
        .from('services')
        .select('id, slug, name, icon, description')
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

    final mostViewedFuture = client
        .from('merchants')
        .select(merchantColumns)
        .eq('status', 'approved')
        .gt('views_count', 0)
        .order('views_count', ascending: false)
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
      servicesFuture,
      categoriesFuture,
      categoryCountsFuture,
      adsFuture,
      featuredFuture,
      newestFuture,
      topOrderedFuture,
      mostViewedFuture,
      nearbyPoolFuture,
    ]);

    final sections = (results[0] as List)
        .map((row) => HomeSection.fromMap(row as Map<String, dynamic>))
        .where((section) => section.key != HomeSectionKey.unknown)
        .toList();

    final services = (results[1] as List)
        .map((row) => AppService.fromMap(row as Map<String, dynamic>))
        .toList();

    final counts = <String, int>{};
    for (final row in results[3] as List) {
      final categoryId = row['category_id'] as String?;
      if (categoryId == null) continue;
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }

    final ads = (results[4] as List)
        .map((row) => Advertisement.fromMap(row as Map<String, dynamic>))
        .where((ad) => ad.isCurrentlyActive)
        .toList();

    return _HomeData(
      sections: sections,
      services: services,
      ads: ads,
      categories: (results[2] as List)
          .map((row) => MerchantCategory.fromMap(row as Map<String, dynamic>))
          .toList(),
      categoryCounts: counts,
      featured: _toMerchants(results[5]),
      newest: _toMerchants(results[6]),
      topOrdered: _toMerchants(results[7]),
      mostViewed: _toMerchants(results[8]),
      nearbyPool: _toMerchants(results[9]),
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
          logoUrl: merchant.logoUrl,
          coverUrl: merchant.coverUrl,
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

  /// خدمات مبنية فعليًا في التطبيق — منفصل تمامًا عن AppService.slug من
  /// قاعدة البيانات (الذي يضبطه الأدمن كـ enabled/disabled). خدمة يفعّلها
  /// الأدمن قبل اكتمال بنائها فعليًا لا يجب أن تفتح شاشة غير موجودة —
  /// راجع تعليق migration 20260824000000_services للسياق الكامل.
  static const _builtServiceSlugs = {'marketplace', 'restaurants'};

  void _openService(AppService service) {
    if (!_builtServiceSlugs.contains(service.slug)) {
      _showComingSoon(service);
      return;
    }

    // كل خدمة مبنية تفتح "تصفّح حسب التصنيف" الخاص بها فقط — Service !=
    // Category (راجع migration 20260824010000_service_categories):
    // Shopping يعرض تصنيفات جذر (بقالة/ملابس/إلكترونيات...)، Restaurants
    // يعرض التصنيفات الفرعية تحت "مطاعم" تحديدًا (بيتزا/مشاوي...) —
    // القرار مبني على service_id بقاعدة البيانات، لا اسم مطابَق بالكود.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllCategoriesScreen(
          locationName: widget.locationName,
          serviceId: service.id,
          topLevelOnly: service.slug != 'restaurants',
          title: service.name,
          showAllMerchantsTile: service.slug != 'restaurants',
        ),
      ),
    );
  }

  void _showComingSoon(AppService service) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ServiceIcon.iconFor(service.slug),
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  service.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).comingSoonMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(AppLocalizations.of(context).ok),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
            tooltip: l10n.notificationsMenuLabel,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: l10n.accountTitle,
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
              return const HomeLoadingSkeleton();
            }

            if (snapshot.hasError) {
              return HomeStateMessage(
                icon: Icons.wifi_off_rounded,
                message: l10n.homeLoadError,
                actionLabel: l10n.retry,
                onAction: _refresh,
              );
            }

            final data = snapshot.data!;
            final nearby = nearestMerchants(data.nearbyPool, _devicePosition);

            // ترتيب الرئيسية المعتمَد: بحث ← إعلان (hero) ← خدمات ← بقية
            // الأقسام الديناميكية — الإعلان يُفصَل عن بقية sectionWidgets
            // عمدًا هنا ليُعرض *قبل* شبكة الخدمات دائمًا، بغضّ النظر عن
            // sort_order النسبي بين hero وبقية الأقسام في home_sections
            // (ترتيب بقية الأقسام فيما بينها يبقى بيد الإدارة كالمعتاد).
            Widget? heroWidget;
            final restWidgets = <Widget>[];
            for (final section in data.sections) {
              final built = _buildSection(section, data, nearby);
              if (built == null) continue;
              if (section.key == HomeSectionKey.hero) {
                heroWidget = built;
              } else {
                restWidgets.add(built);
              }
            }

            final hasAnyContent =
                heroWidget != null ||
                restWidgets.isNotEmpty ||
                data.services.isNotEmpty;

            // حالة فارغة حقيقية واحدة ومميَّزة (لا "قريبًا" مكرَّرة على كل
            // قسم) — تظهر فقط إذا لم يوجد أي محتوى حقيقي إطلاقًا بالصفحة.
            if (!hasAnyContent) {
              return HomeStateMessage(
                icon: Icons.storefront_outlined,
                message: l10n.homeEmptyMessage(widget.locationName),
                actionLabel: l10n.retry,
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
                      child: HomeSearchBar(onTap: _openSearch),
                    ),
                  ),
                  if (heroWidget != null) SliverToBoxAdapter(child: heroWidget),
                  if (data.services.isNotEmpty)
                    SliverToBoxAdapter(
                      child: HomeServicesSection(
                        services: data.services,
                        builtSlugs: _builtServiceSlugs,
                        onTap: _openService,
                      ),
                    ),
                  SliverList.list(children: restWidgets),
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
        return HomeCategoriesSection(
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

      case HomeSectionKey.mostViewed:
        if (data.mostViewed.isEmpty) return null;
        return MerchantSmartSection(
          title: section.title,
          icon: Icons.visibility_rounded,
          merchants: data.mostViewed,
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
  final List<AppService> services;
  final List<Advertisement> ads;
  final List<MerchantCategory> categories;
  final Map<String, int> categoryCounts;
  final List<Merchant> featured;
  final List<Merchant> newest;
  final List<Merchant> topOrdered;
  final List<Merchant> mostViewed;
  final List<Merchant> nearbyPool;

  const _HomeData({
    required this.sections,
    required this.services,
    required this.ads,
    required this.categories,
    required this.categoryCounts,
    required this.featured,
    required this.newest,
    required this.topOrdered,
    required this.mostViewed,
    required this.nearbyPool,
  });
}
