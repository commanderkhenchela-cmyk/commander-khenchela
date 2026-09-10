import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// خريطة OpenStreetMap عامة قابلة لإعادة الاستخدام — تعرض أي مجموعة
/// نقاط مُعطاة (عناوين ثابتة، أو موقع موصّل حيّ يتحرّك). لا مفتاح API
/// ولا حساب Billing — بلاطات OpenStreetMap العامة المجانية مباشرة.
///
/// ملاحظة صدق: خادم tile.openstreetmap.org مخصَّص أصلًا لاستخدام خفيف
/// حسب سياسة OSM نفسها. إن كبر حجم الاستخدام لاحقًا (آلاف الطلبات
/// يوميًا)، الخطوة الطبيعية التالية مزوّد بلاطات تجاري (MapTiler/
/// Stadia/Thunderforest) أو استضافة ذاتية — مجرد تغيير urlTemplate هنا،
/// لا إعادة بناء لأي شاشة تستعمل هذا الـwidget.
class LiveTrackingMap extends StatelessWidget {
  final List<TrackingMarker> markers;
  final double height;

  const LiveTrackingMap({
    super.key,
    required this.markers,
    this.height = 220,
  });

  LatLng _centerOf(List<LatLng> points) {
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) /
        points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();

    final points = markers.map((m) => m.point).toList();
    final center = points.length == 1 ? points.first : _centerOf(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: points.length > 1 ? 13 : 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.commanderkhenchela.customer_app',
            ),
            MarkerLayer(
              markers: markers
                  .map(
                    (m) => Marker(
                      point: m.point,
                      width: 40,
                      height: 40,
                      child: Icon(m.icon, color: m.color, size: 34),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// نقطة واحدة على الخريطة — عنوان ثابت أو موقع موصّل حيّ.
class TrackingMarker {
  final LatLng point;
  final IconData icon;
  final Color color;

  const TrackingMarker({
    required this.point,
    required this.icon,
    required this.color,
  });
}
