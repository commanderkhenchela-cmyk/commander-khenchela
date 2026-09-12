import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver.dart';
import '../models/job_order.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../utils/distance.dart';
import '../widgets/suspended_account_banner.dart';
import 'account_screen.dart';
import 'delivery_requests_home_screen.dart';
import 'job_detail_screen.dart';
import 'notifications_screen.dart';
import 'ride_requests_home_screen.dart';

/// الشاشة الرئيسية للموصّل المعتمَد: مفتاح متصل/غير متصل، وتبويبان
/// ("الطلبات المتاحة" و"طلباتي"). لا استماع لحظي هنا عمدًا (تفاديًا
/// للتعقيد) — Pull-to-refresh يدوي، بالإضافة لتحديث تلقائي بعد كل
/// استلام/تقدّم بحالة طلب.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _locationTimer;

  Driver? _driver;
  bool _isTogglingOnline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDriver();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriver() async {
    final driver = await DriverService.fetchOwnDriver();
    if (!mounted) return;
    setState(() => _driver = driver);
    _syncLocationTimer();
  }

  /// يشتغل فقط أثناء "متصل" وهذه الشاشة مفتوحة — لا تتبّع خلفي إطلاقًا
  /// (قيد معروف، موثَّق في خطة المرحلة 1).
  void _syncLocationTimer() {
    _locationTimer?.cancel();
    if (_driver?.isOnline != true) return;

    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final position = await LocationService.getCurrentPosition();
      if (position == null) return;
      await DriverService.pingLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
    });

    // نبضة فورية عند التفعيل، بدل انتظار أول دقيقة.
    unawaited(_pingOnce());
  }

  Future<void> _pingOnce() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) return;
    await DriverService.pingLocation(
      lat: position.latitude,
      lng: position.longitude,
    );
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isTogglingOnline = true);
    try {
      await DriverService.setOnline(value);
      if (!mounted) return;
      setState(() {
        _driver = Driver(
          id: _driver!.id,
          fullName: _driver!.fullName,
          phone: _driver!.phone,
          vehicleType: _driver!.vehicleType,
          plateNumber: _driver!.plateNumber,
          status: _driver!.status,
          isOnline: value,
          ratingAvg: _driver!.ratingAvg,
          ratingCount: _driver!.ratingCount,
        );
      });
      _syncLocationTimer();
    } finally {
      if (mounted) setState(() => _isTogglingOnline = false);
    }
  }

  void _openJob(String orderId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => JobDetailScreen(orderId: orderId)),
        )
        .then((_) => setState(() {})); // يعيد بناء القوائم عند الرجوع
  }

  /// راجع migration 20260910000000_driver_vehicle_types: bike يرى
  /// orders + اطلب أي شيء، car يرى Taxi فقط، truck لا مجمّع له بعد
  /// (خدمة مستقبلية). قبل تحميل صفّ الموصّل (_driver == null) نعرض
  /// حالة تحميل بدل الافتراض الخاطئ لنوع معيَّن، تفاديًا لومضة محتوى
  /// خاطئ ثم تصحيحه.
  @override
  Widget build(BuildContext context) {
    final isBike = _driver?.isBike ?? false;
    final isCar = _driver?.isCar ?? false;
    final isTruck = _driver?.isTruck ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCar
              ? 'رحلات Taxi'
              : isTruck
              ? 'شحن البضائع'
              : 'الطلبات',
        ),
        actions: [
          if (isBike)
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'طلبات عامة (اطلب أي شيء)',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeliveryRequestsHomeScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'الإشعارات',
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
        ],
        bottom: isBike
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'الطلبات المتاحة'),
                  Tab(text: 'طلباتي'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          const SuspendedAccountBanner(),
          _OnlineToggle(
            isOnline: _driver?.isOnline ?? false,
            isLoading: _isTogglingOnline,
            onChanged: _toggleOnline,
          ),
          Expanded(child: _buildBody(isBike: isBike, isCar: isCar, isTruck: isTruck)),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool isBike,
    required bool isCar,
    required bool isTruck,
  }) {
    if (_driver == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isCar) {
      return _VehicleTypeRedirect(
        icon: Icons.local_taxi_outlined,
        message: 'رحلات Taxi المتاحة تظهر فـ شاشة منفصلة.',
        buttonLabel: 'فتح رحلات Taxi',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RideRequestsHomeScreen()),
          );
        },
      );
    }

    if (isTruck) {
      return const _ComingSoonMessage(
        icon: Icons.local_shipping_outlined,
        message:
            'خدمة التوصيل بالشاحنات قادمة قريبًا. حسابك مسجَّل ومحجوز '
            'مسبقًا — ستصلك إشعار فور إطلاق الخدمة.',
      );
    }

    // bike (أو حساب لم يُحدَّد نوعه بعد — حالة قديمة نادرة، نفس السلوك
    // الافتراضي الأصلي قبل هذه الـmigration).
    return TabBarView(
      controller: _tabController,
      children: [
        _JobsList(
          key: ValueKey('available-${_driver?.isOnline}'),
          fetcher: OrderService.fetchAvailableJobs,
          emptyMessage: 'لا توجد طلبات متاحة حاليًا.',
          onOpen: _openJob,
          claimable: true,
          showDistance: true,
        ),
        _JobsList(
          key: ValueKey('mine-${_driver?.isOnline}'),
          fetcher: OrderService.fetchMyJobs,
          emptyMessage: 'لا توجد طلبات لديك حاليًا.',
          onOpen: _openJob,
          claimable: false,
          showDistance: false,
        ),
      ],
    );
  }
}

/// رسالة + زر توجيه لموصّلي Taxi — بدل عرض تبويبات orders الفارغة
/// (لا معنى لها لسائق سيارة، RLS ترجع فارغًا دائمًا لهذا النوع).
class _VehicleTypeRedirect extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _VehicleTypeRedirect({
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

/// رسالة "قادمة قريبًا" لأنواع مركبات بلا مجمّع طلبات بعد (truck).
class _ComingSoonMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ComingSoonMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black38),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _OnlineToggle({
    required this.isOnline,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: isOnline
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: isOnline ? theme.colorScheme.primary : Colors.black45,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOnline ? 'متصل — تستقبل الطلبات' : 'غير متصل',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOnline ? theme.colorScheme.primary : Colors.black54,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(value: isOnline, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _JobsList extends StatefulWidget {
  final Future<List<JobOrder>> Function() fetcher;
  final String emptyMessage;
  final void Function(String orderId) onOpen;
  final bool claimable;
  final bool showDistance;

  const _JobsList({
    super.key,
    required this.fetcher,
    required this.emptyMessage,
    required this.onOpen,
    required this.claimable,
    required this.showDistance,
  });

  @override
  State<_JobsList> createState() => _JobsListState();
}

class _JobsListState extends State<_JobsList> {
  late Future<List<JobOrder>> _future;
  Position? _currentPosition;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
    if (widget.showDistance) {
      // بصمت: فشل تحديد الموقع هنا لا يمنع عرض القائمة، فقط لا تظهر
      // المسافة — نفس فلسفة LocationService (لا يرمي استثناء أبدًا).
      unawaited(
        LocationService.getCurrentPosition().then((position) {
          if (mounted) setState(() => _currentPosition = position);
        }),
      );
    }
    _subscribeToChanges();
  }

  /// بلا أي filter عمدًا — orders جدول مجمّع (يراه كل الموصّلين
  /// المعتمَدين)، وRLS (orders_select_driver_pool/orders_select_driver_own)
  /// هي من تحصر فعليًا أي صفّ يصل هذا الجهاز؛ نفس مبدأ كل استماعات
  /// المشروع: إعادة جلب صريحة عند أي حدث بدل الثقة بشكل payload مباشرة.
  void _subscribeToChanges() {
    _channel = Supabase.instance.client
        .channel('driver-orders-${widget.claimable}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) unawaited(_refresh());
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.fetcher();
    setState(() => _future = future);
    await future;
  }

  /// null إن كان تحديد الموقع الحالي فشل، أو المحل بلا إحداثيات مسجَّلة
  /// (بعض التجار لم يضبطوا موقعهم بعد) — الاعتماد الوحيد على
  /// merchants.latitude/longitude، وليس عنوان العميل (addresses لا تملك
  /// إحداثيات إطلاقًا).
  String? _distanceLabelFor(JobOrder job) {
    final position = _currentPosition;
    final lat = job.merchantLat;
    final lng = job.merchantLng;
    if (position == null || lat == null || lng == null) return null;
    final km = haversineKm(position.latitude, position.longitude, lat, lng);
    return formatDistance(km);
  }

  Future<void> _claim(JobOrder job) async {
    try {
      await OrderService.claimJob(job.id);
      if (!mounted) return;
      widget.onOpen(job.id);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // نفس نمط _accept فـ delivery_requests_home_screen.dart: رسالة
      // السيرفر الحقيقية أولًا (مثلًا "حسابك موقوف، يرجى التواصل مع
      // الإدارة") — كانت مستبدَلة هنا برسالة عامة مضلِّلة دائمًا،
      // بغضّ النظر عن السبب الفعلي للرفض.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.trim().isNotEmpty
                ? e.message
                : 'تعذّر استلام الطلب — قد يكون استلمه موصّل آخر.',
          ),
        ),
      );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر استلام الطلب — قد يكون استلمه موصّل آخر.'),
        ),
      );
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<JobOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.black45,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تعذّر تحميل الطلبات. اسحب للأسفل لإعادة المحاولة.',
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          final jobs = snapshot.data ?? [];

          if (jobs.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Text(widget.emptyMessage, textAlign: TextAlign.center),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final job = jobs[index];
              final distanceText = _distanceLabelFor(job);
              return Card(
                child: ListTile(
                  onTap: () => widget.onOpen(job.id),
                  title: Text(
                    job.merchantName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      JobOrder.statusLabel(job.status),
                      '${job.totalAmount.toStringAsFixed(0)} دج',
                      ?distanceText,
                    ].join(' — '),
                  ),
                  trailing: widget.claimable
                      ? ElevatedButton(
                          onPressed: () => _claim(job),
                          child: const Text('استلام'),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
