import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/ride_request.dart';
import 'ride_detail_screen.dart';

const _listColumns =
    'id, status, fare, fare_method, created_at, accepted_at, started_at, completed_at, '
    'pickup_address:addresses!pickup_address_id(address_text, communes(name)), '
    'dropoff_address:addresses!dropoff_address_id(address_text, communes(name))';

/// شاشة "رحلاتي" — نفس هيكل MyDeliveryRequestsScreen بالحرف (قائمة
/// واحدة بلا تبويبات/Pagination — حجم متوقَّع صغير لكل عميل).
class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  late Future<List<RideRequest>> _future;
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
        .channel('customer-ride-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_requests',
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

  Future<List<RideRequest>> _fetch() async {
    final data = await Supabase.instance.client
        .from('ride_requests')
        .select(_listColumns)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => RideRequest.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refresh() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myRidesTitle)),
      body: SafeArea(
        child: FutureBuilder<List<RideRequest>>(
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

            final rides = snapshot.data ?? [];

            if (rides.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  children: [
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.noRidesMessage,
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
                itemCount: rides.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _RideCard(ride: rides[index], onReturned: _refresh),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideRequest ride;
  final VoidCallback onReturned;

  const _RideCard({required this.ride, required this.onReturned});

  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (ride.status) {
      case 'completed':
        return theme.colorScheme.primary;
      case 'cancelled':
        return theme.colorScheme.error;
      case 'in_progress':
        return Colors.blue.shade700;
      case 'accepted':
        return Colors.teal.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String get _formattedDate {
    final d = ride.createdAt;
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
            MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id)),
          );
          onReturned();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ride.pickupCommuneName ?? ''} ← ${ride.dropoffCommuneName ?? ''}',
                maxLines: 1,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      RideRequest.statusLabel(ride.status, l10n),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (ride.hasRealFare)
                    Text(
                      l10n.currencyAmount(ride.fare.toStringAsFixed(0)),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
