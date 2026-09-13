import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride_job.dart';
import '../services/location_service.dart';
import '../services/ride_request_service.dart';
import '../widgets/live_tracking_map.dart';
import '../widgets/navigate_button.dart';
import '../widgets/state_message.dart';

/// تفاصيل رحلة Taxi واحدة من منظور الموصّل — زر واحد مطابق للحالة
/// الحالية بالضبط، نفس فلسفة JobDetailScreen: pending -> "قبول"،
/// accepted -> "بدء الرحلة" (+ "التراجع")، in_progress -> "إنهاء
/// الرحلة"، وإلا رسالة الحالة النهائية فقط.
class RideJobDetailScreen extends StatefulWidget {
  final String requestId;

  const RideJobDetailScreen({super.key, required this.requestId});

  @override
  State<RideJobDetailScreen> createState() => _RideJobDetailScreenState();
}

class _RideJobDetailScreenState extends State<RideJobDetailScreen> {
  late Future<RideJob> _future;
  bool _isSubmitting = false;

  // خريطة تتبّع مصغّرة: موقع الموصّل الحيّ (GPS محلي مباشر، بلا عبور
  // قاعدة البيانات — نفس فلسفة LocationService: لا استثناء أبدًا) + نقطتا
  // الانطلاق/الوجهة. تعمل فقط أثناء accepted/in_progress، مطابقةً لشرط
  // NavigateButton، ونفس شرط showDriverTracking فـ ride_detail_screen.dart
  // (customer_app) بالحرف.
  Timer? _locationTimer;
  double? _selfLat;
  double? _selfLng;

  @override
  void initState() {
    super.initState();
    _future = RideRequestService.fetchDetail(widget.requestId).then((data) {
      _syncLocationTimer(data.status);
      return data;
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _syncLocationTimer(String status) {
    final active = status == 'accepted' || status == 'in_progress';
    if (!active) {
      _locationTimer?.cancel();
      _locationTimer = null;
      return;
    }
    if (_locationTimer != null) return;

    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final position = await LocationService.getCurrentPosition();
      if (position == null || !mounted) return;
      setState(() {
        _selfLat = position.latitude;
        _selfLng = position.longitude;
      });
    });

    // نبضة فورية عند بدء التتبّع، بدل انتظار أول 15 ثانية.
    unawaited(_pingSelfLocationOnce());
  }

  Future<void> _pingSelfLocationOnce() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null || !mounted) return;
    setState(() {
      _selfLat = position.latitude;
      _selfLng = position.longitude;
    });
  }

  Future<void> _refresh() async {
    setState(
      () => _future = RideRequestService.fetchDetail(widget.requestId).then((
        data,
      ) {
        _syncLocationTimer(data.status);
        return data;
      }),
    );
  }

  String _friendlyError(Object e, String fallback) {
    if (e is PostgrestException && e.message.trim().isNotEmpty) {
      return e.message;
    }
    return fallback;
  }

  Future<void> _run(Future<void> Function(String) action, String fallback) async {
    setState(() => _isSubmitting = true);
    try {
      await action(widget.requestId);
      await _refresh();
    } catch (e) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e, fallback))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _accept() =>
      _run(RideRequestService.accept, 'تعذّر قبول الرحلة — قد تكون قُبِلت من موصّل آخر.');

  Future<void> _release() async {
    setState(() => _isSubmitting = true);
    try {
      await RideRequestService.release(widget.requestId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'تعذّر التراجع عن هذه الرحلة.'))),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _start() =>
      _run(RideRequestService.start, 'تعذّر بدء الرحلة.');

  Future<void> _complete() =>
      _run(RideRequestService.complete, 'تعذّر إنهاء الرحلة.');

  /// خريطة مصغّرة بنقطتي الانطلاق/الوجهة + موقع الموصّل الحيّ إن توفّر —
  /// تبقى فارغة (لا شيء) بصمت إن لم تتوفر أي إحداثية إطلاقًا، نفس فلسفة
  /// NavigateButton. نسخة خاصة بهذه الشاشة، نفس نمط _buildMap فـ
  /// ride_detail_screen.dart (customer_app) بالحرف.
  Widget _buildMap(RideJob ride) {
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
    if (_selfLat != null && _selfLng != null) {
      markers.add(
        TrackingMarker(
          point: LatLng(_selfLat!, _selfLng!),
          icon: Icons.my_location_rounded,
          color: Colors.blue.shade700,
        ),
      );
    }

    if (markers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiveTrackingMap(markers: markers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الرحلة')),
      body: FutureBuilder<RideJob>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.wifi_off_rounded,
              message: 'تعذّر تحميل تفاصيل الرحلة.',
              action: ElevatedButton(
                onPressed: _refresh,
                child: const Text('إعادة المحاولة'),
              ),
            );
          }

          final ride = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ride.status == 'accepted' || ride.status == 'in_progress')
                _buildMap(ride),
              _SectionCard(
                icon: Icons.trip_origin_rounded,
                title: 'نقطة الانطلاق',
                lines: [
                  if (ride.pickupCommuneName != null && ride.pickupAddressText != null)
                    '${ride.pickupCommuneName} — ${ride.pickupAddressText}',
                  if (ride.pickupPhone != null) ride.pickupPhone!,
                ],
                // التنقّل لنقطة الانطلاق مفيد فقط بعد قبول الرحلة، قبل استلام الراكب.
                action: ride.status == 'accepted'
                    ? NavigateButton(
                        label: 'التنقّل لنقطة الانطلاق',
                        lat: ride.pickupLat,
                        lng: ride.pickupLng,
                        fallbackAddressText: ride.pickupAddressText == null
                            ? null
                            : '${ride.pickupCommuneName} — ${ride.pickupAddressText}',
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.location_on_rounded,
                title: 'الوجهة',
                lines: [
                  if (ride.dropoffCommuneName != null && ride.dropoffAddressText != null)
                    '${ride.dropoffCommuneName} — ${ride.dropoffAddressText}',
                ],
                // التنقّل للوجهة مفيد فقط بعد استلام الراكب فعليًا (الرحلة جارية).
                action: ride.status == 'in_progress'
                    ? NavigateButton(
                        label: 'التنقّل للوجهة',
                        lat: ride.dropoffLat,
                        lng: ride.dropoffLng,
                        fallbackAddressText: ride.dropoffAddressText == null
                            ? null
                            : '${ride.dropoffCommuneName} — ${ride.dropoffAddressText}',
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الأجرة'),
                          Text(
                            '${ride.fare.toStringAsFixed(0)} دج',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      if (ride.driverEarningShare > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'نصيبك',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            Text(
                              '${ride.driverEarningShare.toStringAsFixed(0)} دج',
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ActionButton(
                status: ride.status,
                isSubmitting: _isSubmitting,
                onAccept: _accept,
                onStart: _start,
                onComplete: _complete,
              ),
              if (ride.status == 'accepted') ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _release,
                  child: const Text('التراجع عن هذه الرحلة'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget? action;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.lines,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String status;
  final bool isSubmitting;
  final VoidCallback onAccept;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _ActionButton({
    required this.status,
    required this.isSubmitting,
    required this.onAccept,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final (label, onTap) = switch (status) {
      'pending' => ('قبول هذه الرحلة', onAccept),
      'accepted' => ('بدء الرحلة (استلام الراكب)', onStart),
      'in_progress' => ('إنهاء الرحلة', onComplete),
      _ => (null, null),
    };

    if (label == null || onTap == null) {
      return Text(RideJob.statusLabel(status), textAlign: TextAlign.center);
    }

    return ElevatedButton(
      onPressed: isSubmitting ? null : onTap,
      child: isSubmitting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}
