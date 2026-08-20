import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/order_detail.dart';

/// شاشة تفاصيل طلب واحد — تعرض المنتجات والعنوان، وتسمح للعميل بإلغاء
/// طلبه بنفسه طالما لم يوافق عليه التاجر بعد (pending فقط).
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<CustomerOrderDetail> _orderFuture;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  Future<CustomerOrderDetail> _fetchOrder() async {
    final data = await Supabase.instance.client
        .from('orders')
        .select('''
          id, status, subtotal, delivery_fee, total_amount, created_at,
          merchants(store_name, phone),
          addresses(address_text, communes(name)),
          order_items(quantity, unit_price, subtotal, products(name))
        ''')
        .eq('id', widget.orderId)
        .single();

    return CustomerOrderDetail.fromMap(data);
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نعم، ألغِ الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', widget.orderId);

      if (!mounted) return;
      setState(() {
        _orderFuture = _fetchOrder();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إلغاء الطلب. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: FutureBuilder<CustomerOrderDetail>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('تعذّر تحميل تفاصيل الطلب.'));
          }

          final order = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الحالة', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          CustomerOrder.statusLabel(order.status),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المحل', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          order.merchantName,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (order.merchantPhone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            order.merchantPhone!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عنوان التوصيل', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          '${order.communeName} — ${order.addressText}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المنتجات', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productName} × ${item.quantity}',
                                  ),
                                ),
                                Text('${item.subtotal.toStringAsFixed(0)} دج'),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        _PriceRow(
                          label: 'المجموع الفرعي',
                          value: order.subtotal,
                        ),
                        const SizedBox(height: 4),
                        _PriceRow(
                          label: 'رسوم التوصيل',
                          value: order.deliveryFee,
                        ),
                        const SizedBox(height: 8),
                        _PriceRow(
                          label: 'الإجمالي',
                          value: order.totalAmount,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.canBeCancelledByCustomer) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _isCancelling ? null : _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('إلغاء الطلب'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('${value.toStringAsFixed(0)} دج', style: style),
      ],
    );
  }
}
