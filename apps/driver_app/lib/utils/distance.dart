import 'dart:math';

/// صيغة Haversine لحساب المسافة التقريبية بالكيلومترات بين نقطتَي
/// إحداثيات — نفس دالة تطبيق الزبون حرفيًا. تُستخدم هنا فقط لعرض مسافة
/// الموصّل التقريبية عن موقع المحل (merchants.latitude/longitude)، وليس
/// عن عنوان العميل — جدول addresses لا يملك إحداثيات إطلاقًا.
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
/// كيلومترات برقم عشري واحد.
String formatDistance(double km) {
  if (km < 1) {
    final meters = (km * 1000).round();
    return '$meters م';
  }
  return '${km.toStringAsFixed(1)} كم';
}
