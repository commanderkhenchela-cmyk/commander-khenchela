import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/delivery_request.dart';

const _requestColumns =
    'id, description, status, delivery_fee, delivery_fee_method, created_at, '
    'accepted_at, addresses(address_text, communes(name))';

/// شاشة تفاصيل طلب "اطلب أي شيء" واحد — نفس فلسفة OrderDetailScreen
/// (Realtime لهذا الطلب بالذات + إلغاء ذاتي طالما pending فقط)، لكن
/// أبسط: لا منتجات، ولا تقييم (لا تاجر يُقيَّم هنا).
class DeliveryRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const DeliveryRequestDetailScreen({super.key, required this.requestId});

  @override
  State<DeliveryRequestDetailScreen> createState() =>
      _DeliveryRequestDetailScreenState();
}

class _DeliveryRequestDetailScreenState
    extends State<DeliveryRequestDetailScreen> {
  late Future<DeliveryRequest> _future;
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
        .channel('customer-delivery-request-${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.requestId,
          ),
          callback: (_) {
            if (mounted) setState(() => _future = _fetch());
          },
        )
        .subscribe();
  }

  Future<DeliveryRequest> _fetch() async {
    final row = await Supabase.instance.client
        .from('delivery_requests')
        .select(_requestColumns)
        .eq('id', widget.requestId)
        .single();
    return DeliveryRequest.fromMap(row);
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
          .from('delivery_requests')
          .update({'status': 'cancelled'})
          .eq('id', widget.requestId);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestAnythingTitle)),
      body: SafeArea(
        child: FutureBuilder<DeliveryRequest>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.myOrdersLoadError));
            }

            final request = snapshot.data!;
            final statusColor = _statusColor(context, request.status);

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
                        DeliveryRequest.statusLabel(request.status, l10n),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (request.status == 'pending')
                  Text(
                    l10n.deliveryRequestPendingMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
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
                          l10n.deliveryRequestDescriptionLabel,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(request.description),
                        if (request.addressText != null) ...[
                          const Divider(height: 28),
                          Text(
                            l10n.deliveryAddressLabel,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${request.communeName ?? ''} — ${request.addressText}',
                          ),
                        ],
                        if (request.status != 'pending') ...[
                          const Divider(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.deliveryFeeLabel),
                              Text(
                                request.hasRealFee
                                    ? l10n.currencyAmount(
                                        request.deliveryFee.toStringAsFixed(
                                          0,
                                        ),
                                      )
                                    : l10n.deliveryFeeTbdMessage,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (request.status == 'pending') ...[
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
