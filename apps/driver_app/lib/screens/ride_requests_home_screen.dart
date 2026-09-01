import 'package:flutter/material.dart';

import '../models/ride_job.dart';
import '../services/ride_request_service.dart';
import 'ride_job_detail_screen.dart';

/// شاشة "رحلات Taxi" — نفس هيكل DeliveryRequestsHomeScreen (تبويبان:
/// المتاحة/رحلاتي)، لكن أبسط: كلا التبويبين هنا يفتحان تفاصيل الرحلة
/// مباشرة عند الضغط (لا حاجة لفصل قبول-ثم-تفاصيل كما فـ اطلب أي شيء)
/// لأن عنواني الانطلاق/الوجهة مرئيان أصلًا حتى فـ المجمّع — راجع تعليق
/// RideRequestService. شاشة التفاصيل نفسها هي من تحوي زر "قبول".
class RideRequestsHomeScreen extends StatefulWidget {
  const RideRequestsHomeScreen({super.key});

  @override
  State<RideRequestsHomeScreen> createState() =>
      _RideRequestsHomeScreenState();
}

class _RideRequestsHomeScreenState extends State<RideRequestsHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDetail(String requestId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => RideJobDetailScreen(requestId: requestId),
          ),
        )
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلات Taxi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المتاحة'),
            Tab(text: 'رحلاتي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RidesList(
            fetcher: RideRequestService.fetchAvailable,
            emptyMessage: 'لا توجد رحلات متاحة حاليًا.',
            onOpen: _openDetail,
          ),
          _RidesList(
            fetcher: RideRequestService.fetchMine,
            emptyMessage: 'لا توجد رحلات لديك حاليًا.',
            onOpen: _openDetail,
          ),
        ],
      ),
    );
  }
}

class _RidesList extends StatefulWidget {
  final Future<List<RideJob>> Function() fetcher;
  final String emptyMessage;
  final void Function(String requestId) onOpen;

  const _RidesList({
    required this.fetcher,
    required this.emptyMessage,
    required this.onOpen,
  });

  @override
  State<_RidesList> createState() => _RidesListState();
}

class _RidesListState extends State<_RidesList> {
  late Future<List<RideJob>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
  }

  Future<void> _refresh() async {
    final future = widget.fetcher();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<RideJob>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.black45,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تعذّر تحميل الرحلات. اسحب للأسفل لإعادة المحاولة.',
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          final rides = snapshot.data ?? [];

          if (rides.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Text(widget.emptyMessage, textAlign: TextAlign.center),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return Card(
                child: ListTile(
                  onTap: () => widget.onOpen(ride.id),
                  title: Text(
                    '${ride.pickupCommuneName ?? '؟'} ← ${ride.dropoffCommuneName ?? '؟'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      RideJob.statusLabel(ride.status),
                      '${ride.fare.toStringAsFixed(0)} دج',
                    ].join(' — '),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
