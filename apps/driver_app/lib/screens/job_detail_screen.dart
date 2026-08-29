import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/job_order.dart';
import '../services/order_service.dart';

/// تفاصيل طلبية واحدة من منظور الموصّل: معلومات المحل (الاستلام)،
/// معلومات العميل (التسليم)، المبلغ الإجمالي وحالة الدفع (Cash on
/// Delivery — الموصّل يعرف كم يجمع)، وزر واحد فقط مطابق للحالة الحالية
/// بالضبط (نفس خريطة ADMIN_ACTIONS في لوحة الإدارة، من جهة الموصّل).
class JobDetailScreen extends StatefulWidget {
  final String orderId;

  const JobDetailScreen({super.key, required this.orderId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<JobDetail> _future;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = OrderService.fetchJobDetail(widget.orderId);
  }

  Future<void> _refresh() async {
    setState(() => _future = OrderService.fetchJobDetail(widget.orderId));
  }

  /// رسالة الخطأ الحقيقية عند توفّرها: RPC/trigger يرفضان بـ `raise
  /// exception 'نص عربي واضح'` (مثلاً "هذا الطلب لم يعد متاحًا" أو
  /// "انتقال حالة غير مسموح")، وتصل هنا كـ PostgrestException.message —
  /// أدقّ بكثير من رسالة عامة تخلط بين تعارض حالة حقيقي وعطل شبكة عابر.
  String _friendlyError(Object e, String fallback) {
    if (e is PostgrestException && e.message.trim().isNotEmpty) {
      return e.message;
    }
    return fallback;
  }

  Future<void> _advance(String toStatus) async {
    setState(() => _isSubmitting = true);
    try {
      await OrderService.advanceStatus(widget.orderId, toStatus);
      await _refresh();
    } catch (e) {
      // نحدّث دائمًا بعد فشل: قد يكون السبب أن الإدارة غيّرت الحالة أو
      // أعادت تعيين الطلب لموصّل آخر في نفس اللحظة — التحديث يعكس
      // الوضع الحقيقي بدل ترك الشاشة بحالة قديمة.
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'تعذّر تحديث حالة الطلب.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _release() async {
    setState(() => _isSubmitting = true);
    try {
      await OrderService.releaseJob(widget.orderId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'تعذّر التراجع عن الطلب.'))),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: FutureBuilder<JobDetail>(
        future: _future,
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
                    const Text('تعذّر تحميل تفاصيل الطلب.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final order = detail.order;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                icon: Icons.storefront_rounded,
                title: 'الاستلام من المحل',
                lines: [
                  order.merchantName,
                  if (order.merchantAddressText != null)
                    order.merchantAddressText!,
                  if (order.merchantPhone != null) order.merchantPhone!,
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.person_pin_circle_rounded,
                title: 'التسليم للعميل',
                lines: [
                  '${detail.communeName} — ${detail.customerAddressText}',
                  if (detail.customerPhone != null) detail.customerPhone!,
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.receipt_long_rounded,
                title: 'الطلب',
                lines: [
                  for (final item in detail.items)
                    '${item.productName} × ${item.quantity}',
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.paymentStatus == 'collected'
                                ? 'تم تحصيل المبلغ'
                                : 'المبلغ المطلوب تحصيله (نقدًا)',
                          ),
                          Text(
                            '${order.totalAmount.toStringAsFixed(0)} دج',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      if (order.driverEarningShare > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'نصيبك من رسوم التوصيل',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            Text(
                              '${order.driverEarningShare.toStringAsFixed(0)} دج',
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ActionButton(
                status: order.status,
                isSubmitting: _isSubmitting,
                onAdvance: _advance,
              ),
              if (order.status == 'ready_for_pickup') ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _release,
                  child: const Text('التراجع عن هذا الطلب'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String status;
  final bool isSubmitting;
  final ValueChanged<String> onAdvance;

  const _ActionButton({
    required this.status,
    required this.isSubmitting,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final (label, nextStatus) = switch (status) {
      'ready_for_pickup' => ('تم الاستلام من المحل', 'picked_up'),
      'picked_up' => ('الانطلاق للعميل', 'out_for_delivery'),
      'out_for_delivery' => ('تم التسليم للعميل', 'delivered'),
      _ => (null, null),
    };

    if (label == null || nextStatus == null) {
      return const Text('تم تسليم هذا الطلب.', textAlign: TextAlign.center);
    }

    return ElevatedButton(
      onPressed: isSubmitting ? null : () => onAdvance(nextStatus),
      child: isSubmitting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
