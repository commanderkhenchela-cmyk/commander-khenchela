import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_request_job.dart';
import '../services/delivery_request_service.dart';

/// تفاصيل طلب "اطلب أي شيء" مقبول من الموصّل — تُفتح فقط لطلب مقبول
/// (أو مسلَّم/ملغى) فعليًا، أبدًا لطلب pending فـ المجمع (راجع تعليق
/// DeliveryRequestService لسبب الفصل). زر واحد: "تم التسليم" طالما
/// الحالة accepted.
class DeliveryRequestJobDetailScreen extends StatefulWidget {
  final String requestId;

  const DeliveryRequestJobDetailScreen({super.key, required this.requestId});

  @override
  State<DeliveryRequestJobDetailScreen> createState() =>
      _DeliveryRequestJobDetailScreenState();
}

class _DeliveryRequestJobDetailScreenState
    extends State<DeliveryRequestJobDetailScreen> {
  late Future<DeliveryRequestJob> _future;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = DeliveryRequestService.fetchDetail(widget.requestId);
  }

  Future<void> _refresh() async {
    setState(
      () => _future = DeliveryRequestService.fetchDetail(widget.requestId),
    );
  }

  String _friendlyError(Object e, String fallback) {
    if (e is PostgrestException && e.message.trim().isNotEmpty) {
      return e.message;
    }
    return fallback;
  }

  Future<void> _complete() async {
    setState(() => _isSubmitting = true);
    try {
      await DeliveryRequestService.complete(widget.requestId);
      await _refresh();
    } catch (e) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'تعذّر إتمام الطلب.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: FutureBuilder<DeliveryRequestJob>(
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

          final request = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                icon: Icons.description_outlined,
                title: 'ماذا يريد العميل',
                lines: [request.description],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.person_pin_circle_rounded,
                title: 'التسليم للعميل',
                lines: [
                  if (request.communeName != null &&
                      request.addressText != null)
                    '${request.communeName} — ${request.addressText}',
                  if (request.customerPhone != null) request.customerPhone!,
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نصيبك من رسوم التوصيل'),
                      Text(
                        request.driverEarningShare > 0
                            ? '${request.driverEarningShare.toStringAsFixed(0)} دج'
                            : 'تُحدَّد لاحقًا',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (request.status == 'accepted')
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _complete,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('تم التسليم'),
                )
              else
                Text(
                  DeliveryRequestJob.statusLabel(request.status),
                  textAlign: TextAlign.center,
                ),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
