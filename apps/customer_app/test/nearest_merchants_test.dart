import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:customer_app/models/merchant.dart';
import 'package:customer_app/utils/nearest_merchants.dart';

Position _position(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Merchant _merchant(String id, {double? lat, double? lon}) =>
    Merchant(id: id, storeName: 'محل $id', latitude: lat, longitude: lon);

void main() {
  group('nearestMerchants', () {
    test('قائمة فارغة عند عدم توفّر موقع الجهاز', () {
      final merchants = [_merchant('a', lat: 35.43, lon: 7.14)];
      expect(nearestMerchants(merchants, null), isEmpty);
    });

    test('تتجاهل المحلات التي لم تحفظ موقعها', () {
      final device = _position(35.4333, 7.1417);
      final merchants = [
        _merchant('no-location'),
        _merchant('with-location', lat: 35.4333, lon: 7.1417),
      ];

      final result = nearestMerchants(merchants, device);

      expect(result, hasLength(1));
      expect(result.single.id, 'with-location');
    });

    test('ترتِّب حسب الأقرب فالأبعد', () {
      final device = _position(35.4333, 7.1417);
      final far = _merchant('far', lat: 35.53, lon: 7.24);
      final near = _merchant('near', lat: 35.4335, lon: 7.1419);
      final mid = _merchant('mid', lat: 35.44, lon: 7.15);

      final result = nearestMerchants([far, near, mid], device);

      expect(result.map((m) => m.id), ['near', 'mid', 'far']);
    });

    test('تحترم حدّ العدد الأقصى (limit)', () {
      final device = _position(35.4333, 7.1417);
      final merchants = List.generate(
        12,
        (i) => _merchant('m$i', lat: 35.4333 + i * 0.001, lon: 7.1417),
      );

      final result = nearestMerchants(merchants, device, limit: 5);

      expect(result, hasLength(5));
    });
  });

  group('distanceLabelFor', () {
    test('null عند عدم توفّر موقع الجهاز', () {
      final merchant = _merchant('a', lat: 35.43, lon: 7.14);
      expect(distanceLabelFor(merchant, null), isNull);
    });

    test('null عندما لا يحفظ المحل موقعه', () {
      final device = _position(35.4333, 7.1417);
      final merchant = _merchant('a');
      expect(distanceLabelFor(merchant, device), isNull);
    });

    test('نص مسافة جاهز للعرض عند توفّر الموقعين معًا', () {
      final device = _position(35.4333, 7.1417);
      final merchant = _merchant('a', lat: 35.4333, lon: 7.1417);
      expect(distanceLabelFor(merchant, device), '0 م');
    });
  });
}
