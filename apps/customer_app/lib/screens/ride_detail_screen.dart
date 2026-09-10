import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/ride_request.dart';
import '../widgets/live_tracking_map.dart';

const _rideColumns =
    'id, status, fare, fare_method, created_at, accepted_at, started_at, completed_at, driver_id, '
    'pickup_address:addresses!pickup_address_id(address_text, communes(name), latitude, longitude), '
    'dropoff_address:addresses!dropoff_address_id(address_text, communes(name), latitude, longitude)';

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

  // تتبّع الموصّل الحيّ — راجع migration 20260911000000 لسبب اقتصار
  // هذا على accepted/in_progress بالضبط (RLS drivers_select_via_
  // assigned_ride تفرض نفس الشرط، فلا داعي حتى لمحاولة الجلب خارجه).
  RealtimeChannel? _driverChannel;
  String? _trackedDriverId;
  Map<String, dynamic>? _driverRow;

  @override
  void initState() {
    super.initState();
    _future = _fetch().then((ride) {
      if (ride.canTrackDriverLive) _ensureDriverTracking(ride.driverId!);
      return ride;
    });
    _subscribeToChanges();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    if (_driverChannel != null) {
      Supabase.instance.client.removeChannel(_driverChannel!);
    }
    super.dispose();
  }

  /// يجلب صفّ الموصّل مرّة، ثم يشترك فـ Realtime لتحديث موقعه حيًّا —
  /// مرّة واحدة فقط لكل driverId (تغيّر الحالة إلى in_progress بعد
  /// accepted لا يستلزم اشتراكًا جديدًا، نفس الموصّل).
  Future<void> _ensureDriverTracking(String driverId) async {
    if (_trackedDriverId == driverId) return;
    _trackedDriverId = driverId;

    try {
      final row = await Supabase.instance.client
          .from('drivers')
          .select('id, full_name, phone, current_lat, current_lng')
          .eq('id', driverId)
          .maybeSingle();
      if (mounted && row != null) setState(() => _driverRow = row);
    } catch (_) {
      // بصمت — غياب بطاقة الموصّل لا يجب أن يكسر بقية الشاشة (نفس
      // فلسفة كل استعلامات "إضافية" فـ هذا المشروع).
    }

    _driverChannel = Supabase.instance.client
        .channel('customer-driver-position-$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: driverId,
          ),
          // نفس نمط كل الاشتراكات الأخرى فـ هذا الملف/المشروع: إعادة
          // جلب صريحة بدل الثقة بشكل payload.newRecord مباشرة — أبسط
          // وأكثر اتساقًا، والتكلفة (استعلام صغير إضافي كل تحديث موقع)
          // مقبولة تمامًا لهذا الاستخدام.
          callback: (_) async {
            final row = await Supabase.instance.client
                .from('drivers')
                .select('id, full_name, phone, current_lat, current_lng')
                .eq('id', driverId)
                .maybeSingle();
            if (mounted && row != null) setState(() => _driverRow = row);
          },
        )
        .subscribe();
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
            if (mounted) {
              setState(() {
                _future = _fetch().then((ride) {
                  if (ride.canTrackDriverLive) {
                    _ensureDriverTracking(ride.driverId!);
                  }
                  return ride;
                });
              });
            }
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

  /// خريطة العنوانين + موقع الموصّل الحيّ إن توفّر — تبقى فارغة (لا
  /// شيء) بصمت إن لم تتوفر إحداثيات إطلاقًا (عنوان قديم بلا موقع محفوظ)،
  /// نفس فلسفة كل الحالات "الإضافية غير الحرجة" فـ هذا المشروع.
  Widget _buildMap(RideRequest ride) {
    final markers = <TrackingMarker>[];

    if (ride.pickupLat != null && ride.pickupLng != null) {
      markers.add(
        TrackingMarker(
          point: LatLng(ride.pickupLat!, ride.pickupLng!),
          icon: Icons.trip_origin_rounded,
          color: Colors.green.shade700,
        ),
      );
    }
    if (ride.dropoffLat != null && ride.dropoffLng != null) {
      markers.add(
        TrackingMarker(
          point: LatLng(ride.dropoffLat!, ride.dropoffLng!),
          icon: Icons.location_on_rounded,
          color: Colors.red.shade700,
        ),
      );
    }

    final driverLat = _driverRow?['current_lat'] as num?;
    final driverLng = _driverRow?['current_lng'] as num?;
    if (ride.canTrackDriverLive && driverLat != null && driverLng != null) {
      markers.add(
        TrackingMarker(
          point: LatLng(driverLat.toDouble(), driverLng.toDouble()),
          icon: Icons.two_wheeler_rounded,
          color: Colors.blue.shade700,
        ),
      );
    }

    if (markers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiveTrackingMap(markers: markers),
    );
  }

  Widget _buildDriverCard(ThemeData theme) {
    final row = _driverRow;
    if (row == null) return const SizedBox.shrink();

    final name = row['full_name'] as String?;
    final phone = row['phone'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                child: Icon(
                  Icons.local_taxi_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (phone != null)
                      Text(
                        phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (phone != null)
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => _call(phone),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri.parse('tel:$phone'));
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
                _buildMap(ride),
                _buildDriverCard(theme),
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
