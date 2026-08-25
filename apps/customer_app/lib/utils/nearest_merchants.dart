import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../models/merchant.dart';
import 'distance.dart';

/// المحلات الأقرب لموقع الجهاز الحالي، مرتَّبة تصاعديًا بالمسافة — قائمة
/// فارغة إن لم يتوفّر موقع الجهاز بعد، أو لم يحفظ أي محل موقعه. دالة
/// مشتركة (كانت مكرَّرة بين MerchantsScreen وHomeScreen) حتى يبقى منطق
/// "الأقرب إليك" في مكان واحد.
List<Merchant> nearestMerchants(
  List<Merchant> merchants,
  Position? position, {
  int limit = 8,
}) {
  if (position == null) return [];

  final withLocation = merchants.where((m) => m.hasLocation).toList()
    ..sort((a, b) {
      final distanceA = haversineKm(
        position.latitude,
        position.longitude,
        a.latitude!,
        a.longitude!,
      );
      final distanceB = haversineKm(
        position.latitude,
        position.longitude,
        b.latitude!,
        b.longitude!,
      );
      return distanceA.compareTo(distanceB);
    });

  return withLocation.take(limit).toList();
}

/// نص المسافة الجاهز للعرض بجانب محل معيَّن، أو null إن لم تتوفّر كلتا
/// الإحداثيتين (موقع الجهاز وموقع المحل معًا).
String? distanceLabelFor(
  Merchant merchant,
  Position? position,
  AppLocalizations l10n,
) {
  if (position == null || !merchant.hasLocation) return null;

  return formatDistance(
    haversineKm(
      position.latitude,
      position.longitude,
      merchant.latitude!,
      merchant.longitude!,
    ),
    l10n,
  );
}
