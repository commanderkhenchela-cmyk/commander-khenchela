import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/models/advertisement.dart';

void main() {
  Advertisement makeAd({DateTime? start, DateTime? end}) {
    return Advertisement(
      id: 'ad-1',
      title: 'إعلان تجريبي',
      advertiserName: 'محل تجريبي',
      videoUrl: 'https://example.com/video.mp4',
      startDate: start,
      endDate: end,
    );
  }

  group('Advertisement.isCurrentlyActive', () {
    test('بلا تاريخ بداية أو نهاية → نشط دائمًا', () {
      expect(makeAd().isCurrentlyActive, isTrue);
    });

    test('تاريخ بداية في المستقبل → غير نشط بعد', () {
      final ad = makeAd(start: DateTime.now().add(const Duration(days: 3)));
      expect(ad.isCurrentlyActive, isFalse);
    });

    test('تاريخ بداية في الماضي → نشط', () {
      final ad = makeAd(
        start: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(ad.isCurrentlyActive, isTrue);
    });

    test('تاريخ نهاية في الماضي → انتهى', () {
      final ad = makeAd(end: DateTime.now().subtract(const Duration(days: 2)));
      expect(ad.isCurrentlyActive, isFalse);
    });

    test('تاريخ نهاية اليوم نفسه → لا يزال نشطًا طوال اليوم', () {
      final ad = makeAd(end: DateTime.now());
      expect(ad.isCurrentlyActive, isTrue);
    });

    test('تاريخ نهاية في المستقبل → نشط', () {
      final ad = makeAd(end: DateTime.now().add(const Duration(days: 2)));
      expect(ad.isCurrentlyActive, isTrue);
    });

    test('ضمن نطاق بداية ونهاية معًا → نشط', () {
      final ad = makeAd(
        start: DateTime.now().subtract(const Duration(days: 1)),
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(ad.isCurrentlyActive, isTrue);
    });
  });
}
