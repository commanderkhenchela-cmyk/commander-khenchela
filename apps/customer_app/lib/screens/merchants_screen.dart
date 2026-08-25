import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/merchant.dart';
import '../services/location_service.dart';
import '../theme/design_tokens.dart';
import '../utils/nearest_merchants.dart';
import '../widgets/merchant_card.dart';
import '../widgets/merchant_smart_section.dart';
import '../widgets/search_field.dart';
import 'account_screen.dart';
import 'merchant_products_screen.dart';

const _merchantColumns =
    'id, store_name, phone, communes(name), latitude, longitude, '
    'logo_url, cover_url, rating_avg, rating_count, '
    'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

/// شاشة قائمة المحلات — تُفتح من HomeScreen أو AllCategoriesScreen، إما
/// لتصنيف محدَّد (categoryId) أو لكل المحلات (categoryId = null، بطاقة
/// "كل المحلات"). تجلب فقط المحلات الموافَق عليها من طرف Admin
/// (status = approved)، نفس القاعدة المطبَّقة في RLS على جدول merchants.
///
/// القائمة الرئيسية (كل المحلات / نتائج البحث) مُرقَّمة صفحيًا حقيقيًا
/// عبر .range() — راجع _loadPage. عند فتحها لتصنيف محدَّد، تُضاف فوق
/// القائمة أقسام ذكية أفقية (مميزة/الأكثر طلبًا/مفتوح الآن/الأقرب
/// إليك/المضافة حديثًا)، تُجلَب مرة واحدة فقط ولا تتأثر بالترقيم — كل
/// قسم يظهر فقط إن كانت له بيانات حقيقية.
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
  static const _pageSize = 20;
  static const _debounceDuration = Duration(milliseconds: 400);

  late Future<_MerchantsSections> _sectionsFuture;
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _query = '';
  Position? _devicePosition;

  // القائمة الرئيسية المعروضة حاليًا (تصفّح أو نتائج بحث — وضع واحد في
  // كل لحظة يحدّده _query). غير final فعليًا بمعنى القيمة، لكن الكائن
  // نفسه ثابت ويُعدَّل بمكانه (clear/addAll) بدل استبداله في كل صفحة،
  // حتى لا تُعاد الصفحات السابقة عند طلب صفحة جديدة.
  final List<Merchant> _visible = [];
  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _loadMoreError = false;
  Object? _initialError;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
    _loadPage();
    _searchController.addListener(_onQueryChanged);

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
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final text = _searchController.text.trim();
    _debounce?.cancel();
    if (text == _query) return;
    _debounce = Timer(_debounceDuration, () => _restart(text));
  }

  /// يبدأ من الصفحة الأولى من جديد — عند تغيّر نص البحث فقط (أو زر
  /// إعادة المحاولة على الصفحة الأولى). لا يمسّ الأقسام الذكية (مستقلة
  /// تمامًا عن حالة البحث/الترقيم).
  void _restart(String query) {
    setState(() {
      _query = query;
      _visible.clear();
      _hasMore = true;
      _isInitialLoading = true;
      _loadMoreError = false;
      _initialError = null;
    });
    _loadPage();
  }

  /// يجلب صفحة واحدة (الأولى أو التالية) من القائمة الرئيسية — Pagination
  /// حقيقية عبر .range()، بترتيب ثابت (اسم المحل ثم id كترتيب ثانوي
  /// deterministic يمنع أي تكرار أو فقدان عنصر لو تساوى اسمان). الصفحات
  /// السابقة لا تُعاد جلبها أبدًا — فقط تُلحَق صفحة جديدة بـ_visible.
  Future<void> _loadPage() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = false;
    });

    try {
      final client = Supabase.instance.client;
      var query = client
          .from('merchants')
          .select(_merchantColumns)
          .eq('status', 'approved');
      if (widget.categoryId != null) {
        query = query.eq('category_id', widget.categoryId!);
      }
      if (_query.isNotEmpty) {
        query = query.ilike('store_name', '%$_query%');
      }

      final from = _visible.length;
      final rows = await query
          .order('store_name', ascending: true)
          .order('id', ascending: true)
          .range(from, from + _pageSize - 1);

      final items = (rows as List)
          .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _visible.addAll(items);
        _hasMore = items.length == _pageSize;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_visible.isEmpty) {
          _initialError = e;
          _isInitialLoading = false;
        } else {
          _loadMoreError = true;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// الأقسام الذكية (فوق القائمة الرئيسية) — تُجلَب مرة واحدة فقط عند
  /// فتح الشاشة، مستقلة تمامًا عن ترقيم/تصفية القائمة الرئيسية. لها
  /// معنى فقط داخل تصنيف محدَّد.
  Future<_MerchantsSections> _loadSections() async {
    if (widget.categoryId == null) {
      return const _MerchantsSections(
        featured: [],
        topOrdered: [],
        newest: [],
        pool: [],
      );
    }

    final client = Supabase.instance.client;
    final categoryId = widget.categoryId!;

    final featuredFuture = client
        .from('merchants')
        .select(_merchantColumns)
        .eq('status', 'approved')
        .eq('category_id', categoryId)
        .eq('is_featured', true)
        .order('store_name')
        .limit(8);

    final topOrderedFuture = client
        .from('merchants')
        .select(_merchantColumns)
        .eq('status', 'approved')
        .eq('category_id', categoryId)
        .gt('orders_count', 0)
        .order('orders_count', ascending: false)
        .limit(8);

    final newestFuture = client
        .from('merchants')
        .select(_merchantColumns)
        .eq('status', 'approved')
        .eq('category_id', categoryId)
        .order('created_at', ascending: false)
        .limit(8);

    // عيّنة محدودة (لا التصنيف كاملًا) لاشتقاق "مفتوح الآن" و"الأقرب
    // إليك" محليًا — نفس نمط nearbyPool في home_screen.dart بالضبط:
    // الحسابان غير قابلين للفلترة في SQL مباشرة (يعتمدان على ساعات
    // العمل الحالية/موقع الجهاز محليًا)، وعيّنة معقولة تكفي تمامًا لحجم
    // بيانات خنشلة الحالي بدل تحميل التصنيف كاملًا لأجل هذين القسمين.
    final poolFuture = client
        .from('merchants')
        .select(_merchantColumns)
        .eq('status', 'approved')
        .eq('category_id', categoryId)
        .order('store_name')
        .limit(60);

    final results = await Future.wait([
      featuredFuture,
      topOrderedFuture,
      newestFuture,
      poolFuture,
    ]);

    return _MerchantsSections(
      featured: _toMerchants(results[0]),
      topOrdered: _toMerchants(results[1]),
      newest: _toMerchants(results[2]),
      pool: _toMerchants(results[3]),
    );
  }

  List<Merchant> _toMerchants(List<dynamic> rows) {
    return rows
        .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
        .toList();
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName != null
              ? l10n.categoryInLocationTitle(
                  widget.categoryName!,
                  widget.locationName,
                )
              : l10n.allMerchantsInLocationTitle(widget.locationName),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: l10n.accountTitle,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchField(controller: _searchController),
            ),
            Expanded(child: _buildBody(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isInitialLoading) return const _MerchantsLoadingSkeleton();

    if (_initialError != null) {
      return _StateMessage(
        icon: Icons.wifi_off_rounded,
        message: l10n.merchantsLoadError,
        actionLabel: l10n.retry,
        onAction: () => _restart(_query),
      );
    }

    if (_visible.isEmpty) {
      return _StateMessage(
        icon: _query.isEmpty
            ? Icons.storefront_outlined
            : Icons.search_off_rounded,
        message: _query.isEmpty
            ? l10n.noMerchantsMessage
            : l10n.noResultsFor(_query),
      );
    }

    return FutureBuilder<_MerchantsSections>(
      future: _sectionsFuture,
      builder: (context, snapshot) {
        final sections = snapshot.data;
        final nearest = sections == null
            ? const <Merchant>[]
            : nearestMerchants(sections.pool, _devicePosition);
        final openNow = sections == null
            ? const <Merchant>[]
            : sections.pool.where((m) => m.isOpenNow == true).take(8).toList();
        final showSections =
            _query.isEmpty &&
            sections != null &&
            (sections.featured.isNotEmpty ||
                sections.topOrdered.isNotEmpty ||
                openNow.isNotEmpty ||
                nearest.isNotEmpty ||
                sections.newest.isNotEmpty);

        return CustomScrollView(
          slivers: [
            if (showSections)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (sections.featured.isNotEmpty)
                      MerchantSmartSection(
                        title: l10n.featuredSectionTitle,
                        icon: Icons.star_rounded,
                        merchants: sections.featured,
                        onTapMerchant: _openMerchant,
                      ),
                    if (sections.topOrdered.isNotEmpty)
                      MerchantSmartSection(
                        title: l10n.topOrderedSectionTitle,
                        icon: Icons.local_fire_department_rounded,
                        merchants: sections.topOrdered,
                        onTapMerchant: _openMerchant,
                      ),
                    if (openNow.isNotEmpty)
                      MerchantSmartSection(
                        title: l10n.openNowSectionTitle,
                        icon: Icons.access_time_filled_rounded,
                        merchants: openNow,
                        onTapMerchant: _openMerchant,
                      ),
                    if (nearest.isNotEmpty)
                      MerchantSmartSection(
                        title: l10n.nearestSectionTitle,
                        icon: Icons.near_me_rounded,
                        merchants: nearest,
                        onTapMerchant: _openMerchant,
                      ),
                    if (sections.newest.isNotEmpty)
                      MerchantSmartSection(
                        title: l10n.newestSectionTitle,
                        icon: Icons.fiber_new_rounded,
                        merchants: sections.newest,
                        onTapMerchant: _openMerchant,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            l10n.allMerchantsSectionLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverList.separated(
                itemCount: _visible.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final merchant = _visible[index];
                  return MerchantCard(
                    merchant: merchant,
                    distanceLabel: distanceLabelFor(
                      merchant,
                      _devicePosition,
                      l10n,
                    ),
                    onTap: () => _openMerchant(merchant),
                  );
                },
              ),
            ),
            if (_hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _LoadMoreFooter(
                    isLoading: _isLoadingMore,
                    hasError: _loadMoreError,
                    onTap: _loadPage,
                    l10n: l10n,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// الأقسام الذكية فوق القائمة الرئيسية — راجع _loadSections لتفاصيل كل حقل.
class _MerchantsSections {
  final List<Merchant> featured;
  final List<Merchant> topOrdered;
  final List<Merchant> newest;
  final List<Merchant> pool;

  const _MerchantsSections({
    required this.featured,
    required this.topOrdered,
    required this.newest,
    required this.pool,
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

/// عنصر "تحميل المزيد" أسفل قائمة المحلات — نفس نمط _LoadMoreControl في
/// search_screen.dart بالضبط (زر عادي / مؤشر تحميل / خطأ + إعادة محاولة
/// للصفحة الفاشلة فقط).
class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _LoadMoreFooter({
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
