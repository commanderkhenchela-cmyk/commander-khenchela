import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/ride_request.dart';
import '../utils/distance.dart';
import '../widgets/live_tracking_map.dart';
import '../widgets/rating_badge.dart';
import '../widgets/review_stars.dart';

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
  late Future<_RidePageData> _future;
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
    _future = _fetch().then((data) {
      if (data.ride.canTrackDriverLive) {
        _ensureDriverTracking(data.ride.driverId!);
      }
      return data;
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
          .select(
            'id, full_name, phone, vehicle_type, plate_number, current_lat, '
            'current_lng, rating_avg, rating_count',
          )
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
                .select(
                  'id, full_name, phone, vehicle_type, plate_number, '
                  'current_lat, current_lng, rating_avg, rating_count',
                )
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
                _future = _fetch().then((data) {
                  if (data.ride.canTrackDriverLive) {
                    _ensureDriverTracking(data.ride.driverId!);
                  }
                  return data;
                });
              });
            }
          },
        )
        .subscribe();
  }

  /// يجلب الرحلة + تقييمها الحالي إن وُجد معًا — نفس نمط
  /// OrderDetailScreen._fetchOrder (order_detail_screen.dart) بالحرف.
  Future<_RidePageData> _fetch() async {
    final client = Supabase.instance.client;

    final rideFuture = client
        .from('ride_requests')
        .select(_rideColumns)
        .eq('id', widget.rideId)
        .single();

    final reviewFuture = client
        .from('driver_reviews')
        .select('id, rating, comment')
        .eq('ride_request_id', widget.rideId)
        .maybeSingle();

    final (rideRow, reviewRow) = await (rideFuture, reviewFuture).wait;

    return _RidePageData(
      ride: RideRequest.fromMap(rideRow),
      review: reviewRow == null ? null : DriverReview.fromMap(reviewRow),
    );
  }

  Future<void> _submitReview(int rating, String? comment) async {
    final data = await _future;
    final driverId = data.ride.driverId;
    if (driverId == null) return; // احتياط — completed يستلزم موصّلًا مُعيَّنًا دائمًا.

    try {
      await Supabase.instance.client.from('driver_reviews').insert({
        'ride_request_id': widget.rideId,
        'customer_id': Supabase.instance.client.auth.currentUser!.id,
        'driver_id': driverId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      });

      if (!mounted) return;
      setState(() => _future = _fetch());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).reviewSubmittedThanks),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reviewSubmitError)),
      );
    }
  }

  Future<void> _openReviewDialog() async {
    final result = await showDialog<_RideReviewInput>(
      context: context,
      builder: (dialogContext) => const _RideReviewDialog(),
    );
    if (result == null) return;
    await _submitReview(result.rating, result.comment);
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

  /// وقت الوصول المتوقَّع للموصّل — للوجهة المناسبة حسب مرحلة الرحلة:
  /// accepted (فـ طريقه إليك) → نقطة الانطلاق، in_progress (أنت معه فـ
  /// السيارة) → نقطة الوصول. تقريب صريح من المسافة فقط (راجع تعليق
  /// estimateEtaMinutes) — null بصمت إن نقصت أي إحداثية.
  String? _etaTextFor(
    RideRequest ride,
    Map<String, dynamic> driverRow,
    AppLocalizations l10n,
  ) {
    final driverLat = driverRow['current_lat'] as num?;
    final driverLng = driverRow['current_lng'] as num?;
    if (driverLat == null || driverLng == null) return null;

    final targetLat = ride.status == 'in_progress'
        ? ride.dropoffLat
        : ride.pickupLat;
    final targetLng = ride.status == 'in_progress'
        ? ride.dropoffLng
        : ride.pickupLng;
    if (targetLat == null || targetLng == null) return null;

    final km = haversineKm(
      driverLat.toDouble(),
      driverLng.toDouble(),
      targetLat,
      targetLng,
    );
    return l10n.etaMinutesLabel('${estimateEtaMinutes(km)}');
  }

  Widget _buildDriverCard(
    ThemeData theme,
    RideRequest ride,
    AppLocalizations l10n,
  ) {
    final row = _driverRow;
    if (row == null) return const SizedBox.shrink();

    final name = row['full_name'] as String?;
    final phone = row['phone'] as String?;
    final plateNumber = row['plate_number'] as String?;
    final etaText = _etaTextFor(ride, row, l10n);
    // نفس شرط RatingBadge فـ merchant_card.dart: لا نعرض "0.0" وهميًا
    // لسائق بلا تقييمات بعد (rating_count = 0 لكل موصّل جديد افتراضيًا).
    final ratingCount = (row['rating_count'] as num?)?.toInt() ?? 0;
    final ratingAvg = (row['rating_avg'] as num?)?.toDouble() ?? 0;

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ratingCount > 0) ...[
                          const SizedBox(width: 8),
                          RatingBadge(
                            ratingAvg: ratingAvg,
                            ratingCount: ratingCount,
                          ),
                        ],
                      ],
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
                    if (etaText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              etaText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (plateNumber != null && plateNumber.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          plateNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
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

  /// بطاقة تقييم السائق — تظهر فقط لرحلة مكتملة فعليًا
  /// (ride.canBeReviewed)، نفس نمط قسم التقييم فـ OrderDetailScreen
  /// بالحرف (order_detail_screen.dart): دعوة للتقييم إن لم يُقيَّم بعد،
  /// أو عرض التقييم المُرسَل مسبقًا.
  Widget _buildReviewSection(
    ThemeData theme,
    RideRequest ride,
    DriverReview? review,
    AppLocalizations l10n,
  ) {
    if (!ride.canBeReviewed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: review == null
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.reviewDriverPromptMessage,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _openReviewDialog,
                      child: Text(l10n.rateNowAction),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.yourRatingLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    ReviewStars(rating: review.rating, size: 22),
                    if (review.comment != null) ...[
                      const SizedBox(height: 8),
                      Text(review.comment!),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestRideTitle)),
      body: SafeArea(
        child: FutureBuilder<_RidePageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.myOrdersLoadError));
            }

            final data = snapshot.data!;
            final ride = data.ride;
            final review = data.review;
            final statusColor = _statusColor(context, ride.status);
            // خريطة التتبّع + بطاقة الموصّل ذواتا معنى فقط أثناء الرحلة
            // الفعلية (accepted/in_progress) — بعد الاكتمال/الإلغاء تصبح
            // بيانات آخر موقع معروف مضلِّلة، والمكان الأصح لها هو قسم
            // التقييم بدلًا منها (_buildReviewSection أدناه).
            final showDriverTracking =
                ride.status == 'accepted' || ride.status == 'in_progress';

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
                if (showDriverTracking) ...[
                  _buildMap(ride),
                  _buildDriverCard(theme, ride, l10n),
                ],
                _buildReviewSection(theme, ride, review, l10n),
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

/// حزمة بيانات الشاشة: تفاصيل الرحلة + تقييمها الحالي إن وُجد (null قبل
/// أن تُقيَّم الرحلة من طرف العميل). نفس بنية _OrderPageData
/// (order_detail_screen.dart) بالحرف.
class _RidePageData {
  final RideRequest ride;
  final DriverReview? review;

  const _RidePageData({required this.ride, this.review});
}

/// نتيجة حوار التقييم — rating إجباري (1-5)، comment اختياري. نفس بنية
/// _ReviewInput (order_detail_screen.dart)، مكرَّرة هنا محليًا (لا مشاركة
/// class عبر ملفات) لأن كلا الشاشتين تحتفظ بمنطقها الخاص مستقلًّا، نفس
/// نمط بقية هذا المشروع (كل شاشة تعرّف حواراتها/عناصرها الخاصة).
class _RideReviewInput {
  final int rating;
  final String? comment;

  const _RideReviewInput({required this.rating, this.comment});
}

/// حوار اختيار تقييم (1-5 نجوم) + تعليق اختياري لسائق رحلة — نفس نمط
/// _ReviewDialog (order_detail_screen.dart) بالحرف، لكن لا نص خاص بالمحل
/// فيه (عنوان عام "قيّم تجربتك" يصلح للسائق أيضًا).
class _RideReviewDialog extends StatefulWidget {
  const _RideReviewDialog();

  @override
  State<_RideReviewDialog> createState() => _RideReviewDialogState();
}

class _RideReviewDialogState extends State<_RideReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.rateExperienceTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReviewStars(
            rating: _rating,
            size: 36,
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.commentOptionalHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            _RideReviewInput(rating: _rating, comment: _commentController.text),
          ),
          child: Text(l10n.submitAction),
        ),
      ],
    );
  }
}
