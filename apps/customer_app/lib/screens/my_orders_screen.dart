import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import 'order_detail_screen.dart';

/// شاشة "طلباتي" — قائمة طلبات العميل الحالي فقط (تحميها RLS تلقائيًا،
/// لا يمكن لأي عميل رؤية طلبات عميل آخر مهما حدث في التطبيق نفسه).
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

  Color _statusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status) {
      case 'delivered':
        return theme.colorScheme.primary;
      case 'cancelled':
      case 'rejected':
        return theme.colorScheme.error;
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: FutureBuilder<List<CustomerOrder>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.black45,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذّر تحميل طلباتك. تحقق من اتصالك بالإنترنت.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _ordersFuture = _fetchOrders();
                        });
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد طلبات بعد. تصفّح المحلات وابدأ طلبك الأول!',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: order.id),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _ordersFuture = _fetchOrders();
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order.merchantName,
                              style: theme.textTheme.titleLarge,
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              context,
                              order.status,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            CustomerOrder.statusLabel(order.status),
                            style: TextStyle(
                              color: _statusColor(context, order.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
