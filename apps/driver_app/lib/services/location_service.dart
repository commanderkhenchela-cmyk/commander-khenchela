import 'package:geolocator/geolocator.dart';

/// يجلب موقع الجهاز الحالي — نفس فلسفة LocationService في تطبيق الزبون
/// حرفيًا: لا يرمي أي استثناء أبدًا مهما حدث (خدمة الموقع مقفلة، رفض
/// الإذن، لا إشارة GPS، انتهت المهلة) — يُرجع null بهدوء في كل هذه
/// الحالات، والشاشة المستدعية تتجاهل تحديث الموقع بصمت بدل تعطّل.
///
/// "أثناء الاستخدام" فقط (While In Use) — لا تتبّع خلفي في هذه المرحلة
/// (قيد معروف موثَّق في خطة المرحلة 1: تحديث الموقع يحدث فقط والتطبيق
/// مفتوح على الشاشة الرئيسية).
class LocationService {
  const LocationService._();

  static Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(timeout);
    } catch (_) {
      return null;
    }
  }
}
