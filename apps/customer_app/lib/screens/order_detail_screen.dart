import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/order_detail.dart';
import '../widgets/review_stars.dart';

/// شاشة تفاصيل طلب واحد — تعرض المنتجات والعنوان، وتسمح للعميل بإلغاء
/// طلبه بنفسه طالما لم يوافق عليه التاجر بعد (pending فقط)، وبتقييم
/// المحل بعد تسليم الطلب فعليًا (راجع CustomerOrderDetail.canBeReviewed).
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<_OrderPageData> _orderFuture;
  bool _isCancelling = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
    _subscribeToChanges();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  /// تغيّر حالة هذا الطلب بالذات (تأكيد التاجر، تسليم، إلخ) يحدّث الشاشة
  /// فورًا والعميل واقف فيها — بدل الاعتماد فقط على الرجوع لـ "طلباتي".
  void _subscribeToChanges() {
    _channel = Supabase.instance.client
        .channel('customer-order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) {
            if (mounted) setState(() => _orderFuture = _fetchOrder());
          },
        )
        .subscribe();
  }

  Future<_OrderPageData> _fetchOrder() async {
    final client = Supabase.instance.client;

    final orderFuture = client
        .from('orders')
        .select('''
          id, status, subtotal, delivery_fee, total_amount, created_at,
          merchants(id, store_name, phone),
          addresses(address_text, communes(name)),
          order_items(quantity, unit_price, subtotal, products(name))
        ''')
        .eq('id', widget.orderId)
        .single();

    final reviewFuture = client
        .from('reviews')
        .select('id, rating, comment')
        .eq('order_id', widget.orderId)
        .maybeSingle();

    final (orderRow, reviewRow) = await (orderFuture, reviewFuture).wait;

    return _OrderPageData(
      order: CustomerOrderDetail.fromMap(orderRow),
      review: reviewRow == null ? null : CustomerReview.fromMap(reviewRow),
    );
  }

  Future<void> _submitReview(int rating, String? comment) async {
    final order = (await _orderFuture).order;

    try {
      await Supabase.instance.client.from('reviews').insert({
        'order_id': widget.orderId,
        'customer_id': Supabase.instance.client.auth.currentUser!.id,
        'merchant_id': order.merchantId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      });

      if (!mounted) return;
      setState(() => _orderFuture = _fetchOrder());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('شكرًا على تقييمك!')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إرسال التقييم. حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _openReviewDialog() async {
    final result = await showDialog<_ReviewInput>(
      context: context,
      builder: (dialogContext) => const _ReviewDialog(),
    );
    if (result == null) return;
    await _submitReview(result.rating, result.comment);
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
      body: FutureBuilder<_OrderPageData>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
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
                      'تعذّر تحميل تفاصيل الطلب. تحقق من اتصالك بالإنترنت.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _orderFuture = _fetchOrder()),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final order = snapshot.data!.order;
          final review = snapshot.data!.review;

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
                if (order.canBeReviewed) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: review == null
                          ? Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'كيف كانت تجربتك مع هذا المحل؟',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _openReviewDialog,
                                  child: const Text('قيّم الآن'),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تقييمك',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                ReviewStars(rating: review.rating, size: 22),
                                if (review.comment != null) ...[
                                  const SizedBox(height: 8),
                                  Text(review.comment!),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
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

/// حزمة بيانات الشاشة: تفاصيل الطلب + تقييمه الحالي إن وُجد (null قبل
/// أن يُقيَّم الطلب من طرف العميل).
class _OrderPageData {
  final CustomerOrderDetail order;
  final CustomerReview? review;

  const _OrderPageData({required this.order, this.review});
}

/// نتيجة حوار التقييم — rating إجباري (1-5)، comment اختياري.
class _ReviewInput {
  final int rating;
  final String? comment;

  const _ReviewInput({required this.rating, this.comment});
}

/// حوار اختيار تقييم (1-5 نجوم) + تعليق اختياري، قبل الإرسال الفعلي —
/// الإرسال نفسه يتم من الشاشة المستدعية (OrderDetailScreen) عبر
/// Navigator.pop بالنتيجة، حتى تبقى منطق الشبكة في مكان واحد.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('قيّم تجربتك'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReviewStars(
            rating: _rating,
            size: 36,
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'تعليق (اختياري)...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            _ReviewInput(rating: _rating, comment: _commentController.text),
          ),
          child: const Text('إرسال'),
        ),
      ],
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
