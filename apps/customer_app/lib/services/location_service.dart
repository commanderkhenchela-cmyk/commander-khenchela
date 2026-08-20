import 'package:geolocator/geolocator.dart';

/// يجلب موقع الجهاز الحالي لقسم "الأقرب إليك"، بنفس فلسفة
/// BrandingService/ContactService: لا يرمي أي استثناء أبدًا مهما حدث
/// (خدمة الموقع مقفلة، المستخدم رفض الإذن، لا إشارة GPS، انتهت المهلة)
/// — يُرجع null بهدوء في كل هذه الحالات، والشاشة المستدعية تُخفي قسم
/// "الأقرب إليك" ببساطة، بدل تعطيل التطبيق أو إظهار رسالة خطأ مزعجة.
///
/// لا نطلب "دائمًا" (Always) بل "أثناء الاستخدام" فقط (While In Use) —
/// لا حاجة لموقع في الخلفية إطلاقًا لهذه الميزة.
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
      // أي خطأ غير متوقَّع (منصّة لا تدعم الموقع، Timeout، إلخ) → null
      // بهدوء، بنفس منطق BrandingService.load().
      return null;
    }
  }
}
