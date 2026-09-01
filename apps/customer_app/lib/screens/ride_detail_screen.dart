import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/ride_request.dart';

const _rideColumns =
    'id, status, fare, fare_method, created_at, accepted_at, started_at, completed_at, '
    'pickup_address:addresses!pickup_address_id(address_text, communes(name)), '
    'dropoff_address:addresses!dropoff_address_id(address_text, communes(name))';

/// شاشة تفاصيل رحلة Taxi واحدة — نفس فلسفة DeliveryRequestDetailScreen
/// (Realtime لهذه الرحلة بالذات + إلغاء ذاتي طالما لم تبدأ فعليًا).
class RideDetailScreen extends StatefulWidget {
  final String rideId;

  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  late Future<RideRequest> _future;
  bool _isCancelling = false;
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
    _channel = Supabase.instance.client
        .channel('customer-ride-${widget.rideId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.rideId,
          ),
          callback: (_) {
            if (mounted) setState(() => _future = _fetch());
          },
        )
        .subscribe();
  }

  Future<RideRequest> _fetch() async {
    final row = await Supabase.instance.client
        .from('ride_requests')
        .select(_rideColumns)
        .eq('id', widget.rideId)
        .single();
    return RideRequest.fromMap(row);
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelOrderTitle),
        content: Text(l10n.cancelOrderConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.cancelOrderTitle),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await Supabase.instance.client
          .from('ride_requests')
          .update({'status': 'cancelled'})
          .eq('id', widget.rideId);
      if (mounted) setState(() => _future = _fetch());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cancelOrderError)));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestRideTitle)),
      body: SafeArea(
        child: FutureBuilder<RideRequest>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.myOrdersLoadError));
            }

            final ride = snapshot.data!;
            final statusColor = _statusColor(context, ride.status);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        RideRequest.statusLabel(ride.status, l10n),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.ridePickupLabel,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ride.pickupCommuneName ?? ''} — ${ride.pickupAddressText ?? ''}',
                        ),
                        const Divider(height: 24),
                        Text(
                          l10n.rideDropoffLabel,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ride.dropoffCommuneName ?? ''} — ${ride.dropoffAddressText ?? ''}',
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.rideFareLabel),
                            Text(
                              ride.hasRealFare
                                  ? l10n.currencyAmount(
                                      ride.fare.toStringAsFixed(0),
                                    )
                                  : l10n.deliveryFeeTbdMessage,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (ride.canBeCancelled) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isCancelling ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: _isCancelling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.cancelOrderTitle),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
