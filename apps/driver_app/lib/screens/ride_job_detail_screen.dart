import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride_job.dart';
import '../services/ride_request_service.dart';

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

  @override
  void initState() {
    super.initState();
    _future = RideRequestService.fetchDetail(widget.requestId);
  }

  Future<void> _refresh() async {
    setState(() => _future = RideRequestService.fetchDetail(widget.requestId));
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('تعذّر تحميل تفاصيل الرحلة.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final ride = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                icon: Icons.trip_origin_rounded,
                title: 'نقطة الانطلاق',
                lines: [
                  if (ride.pickupCommuneName != null && ride.pickupAddressText != null)
                    '${ride.pickupCommuneName} — ${ride.pickupAddressText}',
                  if (ride.pickupPhone != null) ride.pickupPhone!,
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.location_on_rounded,
                title: 'الوجهة',
                lines: [
                  if (ride.dropoffCommuneName != null && ride.dropoffAddressText != null)
                    '${ride.dropoffCommuneName} — ${ride.dropoffAddressText}',
                ],
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

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.lines,
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
