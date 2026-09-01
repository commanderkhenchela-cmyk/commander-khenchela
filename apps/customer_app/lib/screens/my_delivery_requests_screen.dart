import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/delivery_request.dart';
import 'delivery_request_detail_screen.dart';

const _listColumns =
    'id, description, status, delivery_fee, delivery_fee_method, created_at, accepted_at';

/// شاشة "طلباتي الحرة" — قائمة طلبات "اطلب أي شيء" الخاصة بالعميل
/// الحالي فقط (RLS delivery_requests_select_own_customer). قائمة واحدة
/// بلا تبويبات/Pagination — حجم متوقَّع صغير جدًا لكل عميل (بخلاف
/// MyOrdersScreen)، فلا داعي لتعقيد الترقيم الصفحي هنا.
class MyDeliveryRequestsScreen extends StatefulWidget {
  const MyDeliveryRequestsScreen({super.key});

  @override
  State<MyDeliveryRequestsScreen> createState() =>
      _MyDeliveryRequestsScreenState();
}

class _MyDeliveryRequestsScreenState extends State<MyDeliveryRequestsScreen> {
  late Future<List<DeliveryRequest>> _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _subscribeToChanges();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribeToChanges() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = Supabase.instance.client
        .channel('customer-delivery-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: userId,
          ),
          callback: (_) {
            if (mounted) setState(() => _future = _fetch());
          },
        )
        .subscribe();
  }

  Future<List<DeliveryRequest>> _fetch() async {
    final data = await Supabase.instance.client
        .from('delivery_requests')
        .select(_listColumns)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => DeliveryRequest.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refresh() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myDeliveryRequestsTitle)),
      body: SafeArea(
        child: FutureBuilder<List<DeliveryRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.myOrdersLoadError),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  children: [
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.noDeliveryRequestsMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _RequestCard(request: requests[index], onReturned: _refresh),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onReturned;

  const _RequestCard({required this.request, required this.onReturned});

  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (request.status) {
      case 'delivered':
        return theme.colorScheme.primary;
      case 'cancelled':
        return theme.colorScheme.error;
      case 'accepted':
        return Colors.blue.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String get _formattedDate {
    final d = request.createdAt;
    return '${_pad(d.day)}/${_pad(d.month)}/${d.year} — ${_pad(d.hour)}:${_pad(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  DeliveryRequestDetailScreen(requestId: request.id),
            ),
          );
          onReturned();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _formattedDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  DeliveryRequest.statusLabel(request.status, l10n),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
