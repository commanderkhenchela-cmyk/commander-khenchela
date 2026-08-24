import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant_category.dart';
import '../utils/merchant_category_icon.dart';
import '../widgets/category_grid_tile.dart';
import 'account_screen.dart';
import 'merchants_screen.dart';

/// شاشة "كل التصنيفات" — شبكة كاملة بكل تصنيفات المحلات، تُفتح من زر
/// "عرض الكل" في قسم التصنيفات بالصفحة الرئيسية (HomeScreen). كانت هذه
/// الشبكة سابقًا *هي* الصفحة الرئيسية نفسها (MerchantCategoriesScreen)؛
/// أُعيد تسميتها وفصلها هنا بعد أن أصبحت الصفحة الرئيسية Feed متعدد
/// الأقسام (تعرض قسم تصنيفات مختصرًا فقط: شرائح أفقية محدودة العدد) —
/// راجع تعليق home_screen.dart. لوحة الإعلانات (AdCarousel) انتقلت
/// بالكامل إلى قسم "hero" في الصفحة الرئيسية، فلم تعد هذه الشاشة بحاجة
/// إليها.
///
/// ملاحظة تصميم مهمة (إصلاح Overflow — راجع CategoryGridTile وملف
/// category_grid_tile_test.dart للإثبات): البطاقة القديمة كانت تضع Text
/// داخل Column عادي بدون Expanded، فكان Flutter يحاول إعطاءه ارتفاعه
/// الطبيعي الكامل؛ عند اسم تصنيف يمتد لسطرين (أو عند تكبير خط النظام،
/// شائع عند كبار السن) يتجاوز مجموع العناصر ارتفاع الخلية الثابتة
/// بنسبة الأبعاد (aspectRatio) فيفيض المحتوى فعليًا. الإصلاح ثلاثي:
/// (1) الاسم الآن داخل Expanded — هذا هو الإصلاح الهيكلي الحقيقي الذي
/// يمنع الفيضان بنيويًا مهما كبر النص، (2) ارتفاع خلية ثابت بالبكسل
/// (mainAxisExtent) محسوب ليتّسع لسطرين مريحين، (3) سقف أعلى لتكبير خط
/// النظام داخل هذه الشبكة تحديدًا (1.25x) — للحفاظ على مظهر مقروء
/// ومتناسق عند إعدادات "خط كبير جدًا"، لا لمنع الانهيار (ذلك مضمون من
/// نقطة 1 أصلاً).
class AllCategoriesScreen extends StatefulWidget {
  final String locationName;

  /// عند تمريره، تُعرض تصنيفات هذه الخدمة فقط (Shopping أو Restaurants
  /// حاليًا) بدل كل التصنيفات — راجع migration 20260824010000
  /// (service_id الجديد على merchant_categories). null = السلوك القديم
  /// (كل التصنيفات، بلا فلترة) — لا يزال مستخدَمًا في مسارات أخرى.
  final String? serviceId;

  /// true (افتراضي): تصنيفات جذر فقط (parent_id فارغ) — سلوك Shopping.
  /// false: تصنيفات فرعية فقط (parent_id غير فارغ) — سلوك Restaurants
  /// (بيتزا/وجبات سريعة... تحت تصنيف "مطاعم" الأب).
  final bool topLevelOnly;

  final String? title;

  /// بلاطة "كل المحلات" الأولى تعني حرفيًا *كل* محلات المنصّة بلا فلترة
  /// خدمة — تُخفى تلقائيًا عند تصفّح خدمة محدَّدة (serviceId != null)
  /// حتى لا تُظهر لعميل يتصفّح "المطاعم" مثلاً محلات تسوّق لا علاقة لها.
  final bool showAllMerchantsTile;

  const AllCategoriesScreen({
    super.key,
    required this.locationName,
    this.serviceId,
    this.topLevelOnly = true,
    this.title,
    this.showAllMerchantsTile = true,
  });

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late Future<_CategoriesData> _dataFuture;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<_CategoriesData> _load() {
    return _fetchData().then((data) {
      if (mounted) _entranceController.forward(from: 0);
      return data;
    });
  }

  Future<_CategoriesData> _fetchData() async {
    final client = Supabase.instance.client;

    var categoriesQuery = client
        .from('merchant_categories')
        .select('id, name, icon')
        .eq('is_active', true);

    if (widget.serviceId != null) {
      categoriesQuery = categoriesQuery.eq('service_id', widget.serviceId!);
    }
    categoriesQuery = widget.topLevelOnly
        ? categoriesQuery.isFilter('parent_id', null)
        : categoriesQuery.not('parent_id', 'is', null);

    final categoriesFuture = categoriesQuery.order(
      'sort_order',
      ascending: true,
    );

    // عدد المحلات لكل تصنيف يُحسب هنا محليًا من قائمة المحلات الموافَق
    // عليها فقط — لا حاجة لدالة group by في قاعدة البيانات عند هذا الحجم
    // من البيانات (نفس منطق البحث الآني المستخدَم في MerchantsScreen).
    final merchantsFuture = client
        .from('merchants')
        .select('category_id')
        .eq('status', 'approved');

    final results = await Future.wait([categoriesFuture, merchantsFuture]);

    final merchantsData = results[1];
    final counts = <String, int>{};
    for (final row in merchantsData) {
      final categoryId = row['category_id'] as String?;
      if (categoryId == null) continue;
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }

    final categories = results[0]
        .map((row) => MerchantCategory.fromMap(row))
        .toList();

    return _CategoriesData(
      categories: categories,
      counts: counts,
      totalMerchants: merchantsData.length,
    );
  }

  void _refresh() => setState(() => _dataFuture = _load());

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? 'كل التصنيفات',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
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
            return const _CategoriesLoadingSkeleton();
          }

          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.wifi_off_rounded,
              message: 'تعذّر تحميل التصنيفات. تحقق من اتصالك بالإنترنت.',
              actionLabel: 'إعادة المحاولة',
              onAction: _refresh,
            );
          }

          final data = snapshot.data!;

          if (data.categories.isEmpty) {
            return const _StateMessage(
              icon: Icons.category_outlined,
              message: 'لا توجد تصنيفات متاحة حاليًا. عد قريبًا!',
            );
          }

          // سقف أعلى لتكبير خط النظام داخل هذه الشبكة فقط — يمنع فيضان
          // البطاقات عند إعدادات "خط كبير جدًا" مع إبقاء بقية الشاشات
          // (مثل قوائم المنتجات) حرّة تكبر بلا سقف كالمعتاد.
          return MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = _columnsFor(constraints.maxWidth);
                  final showAllTile = widget.showAllMerchantsTile;
                  final itemCount =
                      data.categories.length + (showAllTile ? 1 : 0);

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                // ارتفاع ثابت بالبكسل بدل aspectRatio —
                                // يتّسع لسطرين من النص مهما طال، هذا هو
                                // إصلاح الـ Overflow الفعلي (راجع تعليق
                                // أعلى الملف).
                                mainAxisExtent: 152,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final tile = (showAllTile && index == 0)
                                ? CategoryGridTile(
                                    icon: Icons.apps_rounded,
                                    color: theme.colorScheme.primary,
                                    label: 'كل المحلات',
                                    count: data.totalMerchants,
                                    onTap: () => _openMerchants(),
                                  )
                                : Builder(
                                    builder: (context) {
                                      final category =
                                          data.categories[index -
                                              (showAllTile ? 1 : 0)];
                                      return CategoryGridTile(
                                        icon: MerchantCategoryIcon.iconFor(
                                          category,
                                        ),
                                        color: MerchantCategoryIcon.colorFor(
                                          category.id,
                                        ),
                                        label: category.name,
                                        count: data.counts[category.id] ?? 0,
                                        onTap: () => _openMerchants(
                                          categoryId: category.id,
                                          categoryName: category.name,
                                        ),
                                      );
                                    },
                                  );

                            return _StaggeredEntrance(
                              controller: _entranceController,
                              index: index,
                              itemCount: itemCount,
                              child: tile,
                            );
                          }, childCount: itemCount),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  static int _columnsFor(double width) {
    if (width >= 900) return 6;
    if (width >= 600) return 5;
    if (width >= 420) return 4;
    return 3;
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

/// تحريك دخول متدرّج (Fade + Slide خفيف) لبطاقات الشبكة عند أول ظهور —
/// عنصر واحد فقط (AnimationController) يُغذّي كل البطاقات عبر Interval
/// محسوبة من ترتيب كل بطاقة، بدل إنشاء Controller مستقل لكل بطاقة.
class _StaggeredEntrance extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int itemCount;
  final Widget child;

  const _StaggeredEntrance({
    required this.controller,
    required this.index,
    required this.itemCount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // نوزّع التأخير على أول 12 عنصرًا فقط حتى لا يطول انتظار آخر بطاقة في
    // شبكة كبيرة — بعدها تظهر البطاقات معًا دفعة واحدة.
    final staggerIndex = index.clamp(0, 12);
    final start = (staggerIndex / 13) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
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

/// عرض Skeleton بسيط أثناء تحميل التصنيفات لأول مرة، بنفس الشبكة
/// والارتفاع الثابت للبطاقة الحقيقية — يعطي إحساسًا فوريًا بشكل الصفحة.
class _CategoriesLoadingSkeleton extends StatelessWidget {
  const _CategoriesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 152,
      ),
      itemCount: 9,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
