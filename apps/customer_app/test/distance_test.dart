import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/l10n/app_localizations_ar.dart';
import 'package:customer_app/utils/distance.dart';

void main() {
  final l10n = AppLocalizationsAr();

  group('haversineKm', () {
    test('نفس النقطة → مسافة صفر', () {
      expect(haversineKm(35.4333, 7.1417, 35.4333, 7.1417), closeTo(0, 0.001));
    });

    test('مسافة معروفة تقريبيًا بين نقطتين داخل خنشلة (~1 كم)', () {
      // نقطتان بفارق ~0.009 درجة عرض ≈ 1 كم تقريبًا.
      final km = haversineKm(35.4333, 7.1417, 35.4423, 7.1417);
      expect(km, closeTo(1.0, 0.15));
    });
  });

  group('formatDistance', () {
    test('أقل من كيلومتر واحد → أمتار', () {
      expect(formatDistance(0.35, l10n), '350 م');
    });

    test('كيلومتر واحد أو أكثر → كم برقم عشري واحد', () {
      expect(formatDistance(2.34, l10n), '2.3 كم');
    });

    test('حافة الكيلومتر الواحد بالضبط', () {
      expect(formatDistance(1.0, l10n), '1.0 كم');
    });
  });
}
