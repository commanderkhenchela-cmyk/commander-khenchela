import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_request_job.dart';
import '../services/delivery_request_service.dart';
import '../widgets/empty_list_message.dart';
import 'delivery_request_job_detail_screen.dart';

/// شاشة "طلبات عامة" (اطلب أي شيء) — نفس هيكل HomeScreen (تبويبان:
/// المتاحة/طلباتي)، شاشة منفصلة تمامًا عن طلبات orders بدل توسيع
/// TabController الحالي هناك (يبقى 2 كما هو، بلا أي خطر على تدفّق
/// الطلبات الحيّ العامل). يُفتح من زر مخصَّص فـ AppBar الشاشة الرئيسية.
///
/// فرق جوهري عن _JobsList فـ home_screen.dart: تبويب "المتاحة" هنا لا
/// يفتح تفاصيل الطلب عند الضغط على البطاقة إطلاقًا — فقط زر "قبول" —
/// لأن عنوان التسليم غير مرئي بعد لهذا الموصّل قبل القبول (RLS)، فأي
/// شاشة تفاصيل قبل ذلك ستفشل فـ قراءته. راجع تعليق DeliveryRequestService.
class DeliveryRequestsHomeScreen extends StatefulWidget {
  const DeliveryRequestsHomeScreen({super.key});

  @override
  State<DeliveryRequestsHomeScreen> createState() =>
      _DeliveryRequestsHomeScreenState();
}

class _DeliveryRequestsHomeScreenState
    extends State<DeliveryRequestsHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDetail(String requestId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                DeliveryRequestJobDetailScreen(requestId: requestId),
          ),
        )
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات عامة'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المتاحة'),
            Tab(text: 'طلباتي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestsList(
            fetcher: DeliveryRequestService.fetchAvailable,
            emptyMessage: 'لا توجد طلبات عامة متاحة حاليًا.',
            available: true,
            onAccepted: _openDetail,
          ),
          _RequestsList(
            fetcher: DeliveryRequestService.fetchMine,
            emptyMessage: 'لا توجد طلبات عامة لديك حاليًا.',
            available: false,
            onOpen: _openDetail,
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatefulWidget {
  final Future<List<DeliveryRequestJob>> Function() fetcher;
  final String emptyMessage;
  final bool available;
  final void Function(String requestId)? onAccepted;
  final void Function(String requestId)? onOpen;

  const _RequestsList({
    required this.fetcher,
    required this.emptyMessage,
    required this.available,
    this.onAccepted,
    this.onOpen,
  });

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  late Future<List<DeliveryRequestJob>> _future;
  bool _isAccepting = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
    _subscribeToChanges();
  }

  /// بلا أي filter عمدًا — نفس منطق _JobsListState فـ home_screen.dart
  /// بالحرف (delivery_requests جدول مجمّع، وRLS هي من تحصر الرؤية فعليًا).
  void _subscribeToChanges() {
    _channel = Supabase.instance.client
        .channel('driver-delivery-requests-${widget.available}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_requests',
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

  Future<void> _accept(DeliveryRequestJob request) async {
    setState(() => _isAccepting = true);
    try {
      await DeliveryRequestService.accept(request.id);
      if (!mounted) return;
      widget.onAccepted?.call(request.id);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.trim().isNotEmpty
                ? e.message
                : 'تعذّر قبول الطلب — قد يكون قبِله موصّل آخر.',
          ),
        ),
      );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر قبول الطلب — قد يكون قبِله موصّل آخر.'),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<DeliveryRequestJob>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              children: const [
                EmptyListMessage(
                  icon: Icons.wifi_off_rounded,
                  message: 'تعذّر تحميل الطلبات. اسحب للأسفل لإعادة المحاولة.',
                ),
              ],
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return ListView(
              children: [
                EmptyListMessage(
                  icon: Icons.local_shipping_outlined,
                  message: widget.emptyMessage,
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              final typeLabel = DeliveryRequestJob.requestTypeLabel(
                request.requestType,
              );
              return Card(
                child: ListTile(
                  onTap: widget.available
                      ? null
                      : () => widget.onOpen?.call(request.id),
                  leading: Icon(
                    request.isSend
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded,
                  ),
                  title: Text(
                    request.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.available
                        ? [
                            typeLabel,
                            DeliveryRequestJob.statusLabel(request.status),
                          ].join(' — ')
                        : [
                            typeLabel,
                            DeliveryRequestJob.statusLabel(request.status),
                            if (request.driverEarningShare > 0)
                              '${request.driverEarningShare.toStringAsFixed(0)} دج',
                          ].join(' — '),
                  ),
                  trailing: widget.available
                      ? ElevatedButton(
                          onPressed: _isAccepting
                              ? null
                              : () => _accept(request),
                          child: const Text('قبول'),
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
