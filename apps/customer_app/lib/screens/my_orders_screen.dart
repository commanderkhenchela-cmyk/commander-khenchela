import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import 'order_detail_screen.dart';

const _finalStatuses = {'delivered', 'cancelled', 'rejected'};

/// شاشة "طلباتي" — قائمة طلبات العميل الحالي فقط (تحميها RLS تلقائيًا،
/// لا يمكن لأي عميل رؤية طلبات عميل آخر مهما حدث في التطبيق نفسه).
/// مقسَّمة لتبويبين: طلبات نشطة (لم تصل لحالة نهائية بعد) وطلبات سابقة.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<CustomerOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<CustomerOrder>> _fetchOrders() async {
    final data = await Supabase.instance.client
        .from('orders')
        .select(
          'id, status, subtotal, delivery_fee, total_amount, created_at, merchants(store_name)',
        )
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => CustomerOrder.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refresh() => setState(() => _ordersFuture = _fetchOrders());

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الحالية'),
              Tab(text: 'السابقة'),
            ],
          ),
        ),
        body: FutureBuilder<List<CustomerOrder>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: _refresh);
            }

            final orders = snapshot.data ?? [];
            final active = orders
                .where((o) => !_finalStatuses.contains(o.status))
                .toList();
            final past = orders
                .where((o) => _finalStatuses.contains(o.status))
                .toList();

            return TabBarView(
              children: [
                _OrdersList(
                  orders: active,
                  emptyMessage: 'لا توجد طلبات نشطة حاليًا.',
                  onRefresh: _refresh,
                ),
                _OrdersList(
                  orders: past,
                  emptyMessage: 'لا توجد طلبات سابقة بعد.',
                  onRefresh: _refresh,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<CustomerOrder> orders;
  final String emptyMessage;
  final VoidCallback onRefresh;

  const _OrdersList({
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyMessage, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _OrderCard(order: orders[index], onReturned: onRefresh),
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
                    '${order.totalAmount.toStringAsFixed(0)} دج',
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
                      CustomerOrder.statusLabel(order.status),
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black45),
            const SizedBox(height: 16),
            const Text(
              'تعذّر تحميل طلباتك. تحقق من اتصالك بالإنترنت.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
