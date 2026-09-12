import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/ride_request.dart';
import '../theme/design_tokens.dart';
import '../utils/pagination.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/load_more_footer.dart';
import '../widgets/state_message.dart';
import 'ride_detail_screen.dart';

const _finalStatuses = {'completed', 'cancelled'};
const _listColumns =
    'id, status, fare, fare_method, created_at, accepted_at, started_at, completed_at, '
    'pickup_address:addresses!pickup_address_id(address_text, communes(name)), '
    'dropoff_address:addresses!dropoff_address_id(address_text, communes(name))';

/// شاشة "رحلاتي" — نفس بنية MyOrdersScreen بالحرف (تبويب "الحالية" بلا
/// ترقيم صفحي + تبويب "السابقة" مُرقَّم فعليًا عبر .range()) — راجع
/// تعليقات my_orders_screen.dart للمنطق الكامل، هنا نفس الشيء بالضبط
/// على ride_requests بدل orders.
class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  static const _pastPageSize = 15;

  Future<List<RideRequest>>? _activeFuture;

  final List<RideRequest> _past = [];
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
            if (!mounted) return;
            setState(() => _activeFuture = _fetchActive());
            _restartPast();
          },
        )
        .subscribe();
  }

  Future<List<RideRequest>> _fetchActive() async {
    final data = await Supabase.instance.client
        .from('ride_requests')
        .select(_listColumns)
        .not('status', 'in', '(${_finalStatuses.join(',')})')
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => RideRequest.fromMap(row as Map<String, dynamic>))
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
          .from('ride_requests')
          .select(_listColumns)
          .inFilter('status', _finalStatuses.toList())
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + _pastPageSize - 1);

      final items = (data as List)
          .map((row) => RideRequest.fromMap(row as Map<String, dynamic>))
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
          title: Text(l10n.myRidesTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.activeOrdersTab),
              Tab(text: l10n.pastOrdersTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<RideRequest>>(
              future: _activeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return StateMessage(icon: Icons.wifi_off_rounded, message: l10n.myOrdersLoadError, action: ElevatedButton(onPressed: _refreshActive, child: Text(l10n.retry)));
                }
                return _RidesList(
                  rides: snapshot.data ?? [],
                  emptyMessage: l10n.noActiveRidesMessage,
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
              icon: Icons.local_taxi_outlined,
              message: l10n.noRidesMessage,
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
              child: LoadMoreFooter(
                isLoading: _isLoadingMorePast,
                hasError: _loadMorePastError,
                onTap: _loadPastPage,
                l10n: l10n,
              ),
            );
          }
          return _RideCard(ride: _past[index], onReturned: _restartPast);
        },
      ),
    );
  }
}

class _RidesList extends StatelessWidget {
  final List<RideRequest> rides;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onReturned;

  const _RidesList({
    required this.rides,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onReturned,
  });

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            EmptyListMessage(
              icon: Icons.local_taxi_outlined,
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
        itemCount: rides.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _RideCard(ride: rides[index], onReturned: onReturned),
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
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
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
                      borderRadius: AppRadius.pillAll,
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


