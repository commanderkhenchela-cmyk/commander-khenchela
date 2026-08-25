import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../theme/design_tokens.dart';
import 'order_detail_screen.dart';

const _finalStatuses = {'delivered', 'cancelled', 'rejected'};
const _orderColumns =
    'id, status, subtotal, delivery_fee, total_amount, created_at, merchants(store_name)';

/// شاشة "طلباتي" — قائمة طلبات العميل الحالي فقط (تحميها RLS تلقائيًا،
/// لا يمكن لأي عميل رؤية طلبات عميل آخر مهما حدث في التطبيق نفسه).
/// مقسَّمة لتبويبين بمنطق مختلف عمدًا:
///
/// - "الحالية": طلبات لم تصل لحالة نهائية بعد — عدد صغير طبيعيًا (لا
///   يملك عميل مئات الطلبات النشطة في نفس اللحظة)، فتُجلَب كاملة دفعة
///   واحدة، بلا حاجة لأي Pagination فعلي.
/// - "السابقة": تكبر بلا حدّ نظري مع الوقت (كل طلب مكتمل/ملغى يُضاف
///   إليها للأبد) — هذه فعليًا المُرقَّمة صفحيًا (راجع _loadPastPage).
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static const _pastPageSize = 15;

  Future<List<CustomerOrder>>? _activeFuture;

  final List<CustomerOrder> _past = [];
  bool _hasMorePast = true;
  bool _isInitialLoadingPast = true;
  bool _isLoadingMorePast = false;
  bool _loadMorePastError = false;
  Object? _initialPastError;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _activeFuture = _fetchActive();
    _loadPastPage();
    _subscribeToChanges();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  /// أي تغيير حالة على طلبات هذا العميل (تأكيد التاجر، تسليم، إلخ) يحدّث
  /// القائمتين فورًا بدل انتظار فتح الشاشة يدويًا — نفس فلسفة شاشة
  /// الإشعارات. القائمة "السابقة" تُعاد للصفحة الأولى عند أي تحديث بدل
  /// محاولة دمج التغيير داخل صفحات مُحمَّلة مسبقًا (أبسط وأصحّ من حساب
  /// أين بالضبط يجب إدراج/نقل صفّ ضمن ترقيم صفحي قائم، وحدث نادر أصلًا).
  void _subscribeToChanges() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = Supabase.instance.client
        .channel('customer-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: userId,
          ),
          callback: (_) {
            if (!mounted) return;
            setState(() => _activeFuture = _fetchActive());
            _restartPast();
          },
        )
        .subscribe();
  }

  Future<List<CustomerOrder>> _fetchActive() async {
    final data = await Supabase.instance.client
        .from('orders')
        .select(_orderColumns)
        .not('status', 'in', '(${_finalStatuses.join(',')})')
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => CustomerOrder.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refreshActive() => setState(() => _activeFuture = _fetchActive());

  /// يبدأ ترقيم "السابقة" من الصفحة الأولى من جديد (سحب-للتحديث، إعادة
  /// محاولة، أو حدث Realtime).
  void _restartPast() {
    setState(() {
      _past.clear();
      _hasMorePast = true;
      _isInitialLoadingPast = true;
      _loadMorePastError = false;
      _initialPastError = null;
    });
    _loadPastPage();
  }

  /// يجلب صفحة واحدة من الطلبات السابقة — Pagination حقيقية عبر
  /// .range()، بترتيب ثابت (created_at ثم id كترتيب ثانوي deterministic
  /// يمنع أي تكرار أو فقدان طلب لو تساوى وقتا إنشاء طلبين). لا تُعاد
  /// الصفحات السابقة أبدًا، فقط تُلحَق صفحة جديدة.
  Future<void> _loadPastPage() async {
    if (_isLoadingMorePast || !_hasMorePast) return;

    setState(() {
      _isLoadingMorePast = true;
      _loadMorePastError = false;
    });

    try {
      final from = _past.length;
      final data = await Supabase.instance.client
          .from('orders')
          .select(_orderColumns)
          .inFilter('status', _finalStatuses.toList())
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + _pastPageSize - 1);

      final items = (data as List)
          .map((row) => CustomerOrder.fromMap(row as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _past.addAll(items);
        _hasMorePast = items.length == _pastPageSize;
        _isInitialLoadingPast = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_past.isEmpty) {
          _initialPastError = e;
          _isInitialLoadingPast = false;
        } else {
          _loadMorePastError = true;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoadingMorePast = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myOrdersTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.activeOrdersTab),
              Tab(text: l10n.pastOrdersTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<CustomerOrder>>(
              future: _activeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _refreshActive);
                }
                return _OrdersList(
                  orders: snapshot.data ?? [],
                  emptyMessage: l10n.noActiveOrdersMessage,
                  onRefresh: () async => _refreshActive(),
                  onReturned: _refreshActive,
                );
              },
            ),
            _buildPastTab(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildPastTab(AppLocalizations l10n) {
    if (_isInitialLoadingPast) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initialPastError != null) {
      return _ErrorState(onRetry: _restartPast);
    }

    if (_past.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _restartPast(),
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.noPastOrdersMessage,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final hasMore = _hasMorePast;

    return RefreshIndicator(
      onRefresh: () async => _restartPast(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _past.length + (hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _past.length) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _LoadMoreFooter(
                isLoading: _isLoadingMorePast,
                hasError: _loadMorePastError,
                onTap: _loadPastPage,
                l10n: l10n,
              ),
            );
          }
          return _OrderCard(order: _past[index], onReturned: _restartPast);
        },
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<CustomerOrder> orders;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onReturned;

  const _OrdersList({
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onReturned,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(emptyMessage, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _OrderCard(order: orders[index], onReturned: onReturned),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CustomerOrder order;
  final VoidCallback onReturned;

  const _OrderCard({required this.order, required this.onReturned});

  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (order.status) {
      case 'delivered':
        return theme.colorScheme.primary;
      case 'cancelled':
      case 'rejected':
        return theme.colorScheme.error;
      default:
        return Colors.orange.shade800;
    }
  }

  IconData get _statusIcon {
    switch (order.status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'preparing':
        return Icons.soup_kitchen_outlined;
      case 'ready_for_pickup':
        return Icons.inventory_2_outlined;
      case 'picked_up':
      case 'out_for_delivery':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.task_alt_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String get _shortId => '#${order.id.substring(0, 8).toUpperCase()}';

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String get _formattedDate {
    final d = order.createdAt;
    return '${_pad(d.day)}/${_pad(d.month)}/${d.year} — ${_pad(d.hour)}:${_pad(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order.id),
            ),
          );
          onReturned();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.merchantName,
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_shortId  •  $_formattedDate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.currencyAmount(order.totalAmount.toStringAsFixed(0)),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 15, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      CustomerOrder.statusLabel(order.status, l10n),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نفس نمط _LoadMoreFooter في merchants_screen.dart/_LoadMoreControl في
/// search_screen.dart — زر عادي / مؤشر تحميل / خطأ + إعادة محاولة
/// للصفحة الفاشلة فقط.
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black45),
            const SizedBox(height: 16),
            Text(l10n.myOrdersLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
