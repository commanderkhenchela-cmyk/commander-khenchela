import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/craftsman_request.dart';
import 'craftsman_request_detail_screen.dart';

const _listColumns =
    'id, craft_type, description, status, assigned_craftsman_name, '
    'assigned_craftsman_phone, created_at, assigned_at, completed_at';

/// شاشة "طلبات الحرفيين" — نفس هيكل MyDeliveryRequestsScreen بالحرف.
class MyCraftsmanRequestsScreen extends StatefulWidget {
  const MyCraftsmanRequestsScreen({super.key});

  @override
  State<MyCraftsmanRequestsScreen> createState() =>
      _MyCraftsmanRequestsScreenState();
}

class _MyCraftsmanRequestsScreenState
    extends State<MyCraftsmanRequestsScreen> {
  late Future<List<CraftsmanRequest>> _future;
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
        .channel('customer-craftsman-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'craftsman_requests',
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

  Future<List<CraftsmanRequest>> _fetch() async {
    final data = await Supabase.instance.client
        .from('craftsman_requests')
        .select(_listColumns)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => CraftsmanRequest.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refresh() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myCraftsmanRequestsTitle)),
      body: SafeArea(
        child: FutureBuilder<List<CraftsmanRequest>>(
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
                        l10n.noCraftsmanRequestsMessage,
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
  final CraftsmanRequest request;
  final VoidCallback onReturned;

  const _RequestCard({required this.request, required this.onReturned});

  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (request.status) {
      case 'completed':
        return theme.colorScheme.primary;
      case 'cancelled':
        return theme.colorScheme.error;
      case 'assigned':
        return Colors.teal.shade700;
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
                  CraftsmanRequestDetailScreen(requestId: request.id),
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
                CraftsmanRequest.craftTypeLabel(request.craftType, l10n),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                request.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
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
                  CraftsmanRequest.statusLabel(request.status, l10n),
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
