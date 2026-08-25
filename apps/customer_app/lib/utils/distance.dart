import 'dart:math';

import '../l10n/app_localizations.dart';

/// صيغة Haversine لحساب المسافة التقريبية بالكيلومترات بين نقطتَي إحداثيات
/// (خط عرض/خط طول) على سطح الأرض. دقّة كافية جدًا لغرض "الأقرب إليك"
/// داخل مدينة واحدة — لا حاجة لأي مكتبة خرائط خارجية لمجرد حساب مسافة.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;

  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * pi / 180;

/// تنسيق مسافة للعرض في الواجهة — أمتار تحت الكيلومتر الواحد، وإلا
/// كيلومترات برقم عشري واحد. يأخذ [AppLocalizations] بدل الاعتماد على
/// BuildContext مباشرة (نفس نمط CustomerOrder.statusLabel) — يبقي هذا
/// الملف Dart خالص بلا اعتماد على شجرة الـWidgets، وقابلًا للاختبار
/// بوحدات دون Widget pump.
String formatDistance(double km, AppLocalizations l10n) {
  if (km < 1) {
    final meters = (km * 1000).round();
    return l10n.distanceMeters('$meters');
  }
  return l10n.distanceKm(km.toStringAsFixed(1));
}
