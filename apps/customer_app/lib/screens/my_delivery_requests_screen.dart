import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/delivery_request.dart';
import '../theme/design_tokens.dart';
import '../utils/pagination.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/state_message.dart';
import 'delivery_request_detail_screen.dart';

const _finalStatuses = {'delivered', 'cancelled'};
const _listColumns =
    'id, description, status, request_type, destination_text, delivery_fee, '
    'delivery_fee_method, created_at, accepted_at';

/// شاشة "طلباتي الحرة" — نفس بنية MyOrdersScreen بالحرف (تبويب "الحالية"
/// بلا ترقيم صفحي + تبويب "السابقة" مُرقَّم فعليًا عبر .range()) — راجع
/// تعليقات my_orders_screen.dart للمنطق الكامل، هنا نفس الشيء بالضبط
/// على delivery_requests بدل orders.
class MyDeliveryRequestsScreen extends StatefulWidget {
  const MyDeliveryRequestsScreen({super.key});

  @override
  State<MyDeliveryRequestsScreen> createState() =>
      _MyDeliveryRequestsScreenState();
}

class _MyDeliveryRequestsScreenState extends State<MyDeliveryRequestsScreen> {
  static const _pastPageSize = 15;

  Future<List<DeliveryRequest>>? _activeFuture;

  final List<DeliveryRequest> _past = [];
  bool _hasMorePast = true;
  bool _isInitialLoadingPast = true;
  bool _isLoadingMorePast = false;
  bool _loadMorePastError = false;
  Object? _initialPastError;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _activeFuture = _fetchActive();
    _loadPastPage();
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
            if (!mounted) return;
            setState(() => _activeFuture = _fetchActive());
            _restartPast();
          },
        )
        .subscribe();
  }

  Future<List<DeliveryRequest>> _fetchActive() async {
    final data = await Supabase.instance.client
        .from('delivery_requests')
        .select(_listColumns)
        .not('status', 'in', '(${_finalStatuses.join(',')})')
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => DeliveryRequest.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refreshActive() => setState(() => _activeFuture = _fetchActive());

  void _restartPast() {
    setState(() {
      _past.clear();
      _hasMorePast = true;
      _isInitialLoadingPast = true;
      _loadMorePastError = false;
      _initialPastError = null;
    });
    _loadPastPage();
  }

  Future<void> _loadPastPage() async {
    if (_isLoadingMorePast || !_hasMorePast) return;

    setState(() {
      _isLoadingMorePast = true;
      _loadMorePastError = false;
    });

    try {
      final from = _past.length;
      final data = await Supabase.instance.client
          .from('delivery_requests')
          .select(_listColumns)
          .inFilter('status', _finalStatuses.toList())
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + _pastPageSize - 1);

      final items = (data as List)
          .map((row) => DeliveryRequest.fromMap(row as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _past.addAll(items);
        _hasMorePast = hasMorePages(
          fetchedCount: items.length,
          pageSize: _pastPageSize,
        );
        _isInitialLoadingPast = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_past.isEmpty) {
          _initialPastError = e;
          _isInitialLoadingPast = false;
        } else {
          _loadMorePastError = true;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoadingMorePast = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myDeliveryRequestsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.activeOrdersTab),
              Tab(text: l10n.pastOrdersTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<DeliveryRequest>>(
              future: _activeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return StateMessage(icon: Icons.wifi_off_rounded, message: l10n.myOrdersLoadError, action: ElevatedButton(onPressed: _refreshActive, child: Text(l10n.retry)));
                }
                return _RequestsList(
                  requests: snapshot.data ?? [],
                  emptyMessage: l10n.noActiveDeliveryRequestsMessage,
                  onRefresh: () async => _refreshActive(),
                  onReturned: _refreshActive,
                );
              },
            ),
            _buildPastTab(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildPastTab(AppLocalizations l10n) {
    if (_isInitialLoadingPast) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initialPastError != null) {
      return StateMessage(icon: Icons.wifi_off_rounded, message: l10n.myOrdersLoadError, action: ElevatedButton(onPressed: _restartPast, child: Text(l10n.retry)));
    }

    if (_past.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _restartPast(),
        child: ListView(
          children: [
            EmptyListMessage(
              icon: Icons.local_shipping_outlined,
              message: l10n.noDeliveryRequestsMessage,
            ),
          ],
        ),
      );
    }

    final hasMore = _hasMorePast;

    return RefreshIndicator(
      onRefresh: () async => _restartPast(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _past.length + (hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _past.length) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _LoadMoreFooter(
                isLoading: _isLoadingMorePast,
                hasError: _loadMorePastError,
                onTap: _loadPastPage,
                l10n: l10n,
              ),
            );
          }
          return _RequestCard(request: _past[index], onReturned: _restartPast);
        },
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final List<DeliveryRequest> requests;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onReturned;

  const _RequestsList({
    required this.requests,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onReturned,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            EmptyListMessage(
              icon: Icons.local_shipping_outlined,
              message: emptyMessage,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _RequestCard(request: requests[index], onReturned: onReturned),
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
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
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
              Row(
                children: [
                  Icon(
                    request.isSend
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DeliveryRequest.requestTypeLabel(
                      request.requestType,
                      l10n,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
                  borderRadius: AppRadius.pillAll,
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

/// نفس نمط _LoadMoreFooter فـ my_orders_screen.dart بالحرف.
class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _LoadMoreFooter({
    required this.isLoading,
    required this.hasError,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Column(
            children: [
              Text(
                l10n.loadMoreError,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(onPressed: onTap, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(l10n.loadMoreAction),
        ),
      ),
    );
  }
}

