import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../services/location_service.dart';

/// مركز خنشلة تقريبيًا — نقطة بداية افتراضية بحتة (لا معنى دقيق لها)
/// تُستخدَم فقط حين لا نملك أي إحداثية أخرى (لا عنوان قائم يُعدَّل، ولا
/// موقع GPS حالي متاح) — أفضل من نقطة عشوائية فـ المحيط أو (0, 0).
const _khenchelaFallbackCenter = LatLng(35.4325, 7.1428);

/// شاشة اختيار نقطة حرّة على خريطة OpenStreetMap — بديل "موقعي الحالي"
/// لعنوان العميل ليس واقفًا عنده فعليًا (عنوان صديق/قريب، أو مكان
/// تسليم بعيد عن موقعه الآن). نمط "الدبّوس الثابت فـ المنتصف + تحريك
/// الخريطة تحته" (نفس أسلوب أغلب منتقيات المواقع المعروفة) — أبسط
/// وأكثر موثوقية من سحب Marker فوق الخريطة (لا تعارض بين لفتة السحب
/// ولفتة تحريك الخريطة نفسها).
///
/// تُرجع [LatLng] عبر Navigator.pop عند التأكيد، أو null إن أُلغيَت.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  late LatLng _center;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _center = _khenchelaFallbackCenter;
      // بصمت: لا موقع أولي معروف — نحاول موقع الجهاز الحالي كبداية
      // أفضل، لكن فشله لا يمنع الاستعمال إطلاقًا (نفس فلسفة
      // LocationService عبر المشروع كله) — يبقى المستخدم قادرًا على
      // تحريك الخريطة يدويًا لأي نقطة بغضّ النظر.
      _tryCurrentLocation();
    }
  }

  Future<void> _tryCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _isLocating = false);
    if (position != null) {
      final moved = LatLng(position.latitude, position.longitude);
      _center = moved;
      _mapController.move(moved, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationPickerTitle)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
              // لا setState هنا عمدًا — لا حاجة لإعادة بناء الواجهة أثناء
              // كل حركة تحريك، فقط نحتفظ بآخر مركز لحظة الضغط على "تأكيد".
              onPositionChanged: (camera, hasGesture) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.commanderkhenchela.customer_app',
              ),
            ],
          ),
          // الدبّوس الثابت — لا يتفاعل مع اللمس (IgnorePointer) حتى لا
          // يمنع لفتات تحريك الخريطة تحته. إزاحة لأسفل تقريبية لتقع رأس
          // الدبّوس (لا مركزه) عند نقطة الاختيار الفعلية.
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_on_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
          ),
          if (_isLocating)
            const Positioned(
              top: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_center),
              child: Text(l10n.confirmLocationAction),
            ),
          ),
        ],
      ),
    );
  }
}
