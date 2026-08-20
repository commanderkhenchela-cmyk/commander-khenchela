import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/models/merchant_business_hours.dart';
import 'package:customer_app/utils/merchant_open_status.dart';

void main() {
  // الثلاثاء 2026-08-25 الساعة 12:00 — يوم ثابت للاختبار (weekday % 7 = 2).
  final tuesdayNoon = DateTime(2026, 8, 25, 12, 0);

  group('MerchantOpenStatus.isOpenNow', () {
    test('لا معلومات إطلاقًا → null (غير معروف، وليس مغلق)', () {
      expect(MerchantOpenStatus.isOpenNow([], now: tuesdayNoon), isNull);
    });

    test('لا يوجد صف لليوم الحالي تحديدًا → null', () {
      final hours = [
        const MerchantBusinessHours(
          dayOfWeek: 0, // الأحد فقط — لا الثلاثاء
          openTime: '09:00',
          closeTime: '18:00',
          isClosed: false,
        ),
      ];
      expect(MerchantOpenStatus.isOpenNow(hours, now: tuesdayNoon), isNull);
    });

    test('يوم عطلة صريح (is_closed) → false', () {
      final hours = [
        const MerchantBusinessHours(
          dayOfWeek: 2,
          openTime: null,
          closeTime: null,
          isClosed: true,
        ),
      ];
      expect(MerchantOpenStatus.isOpenNow(hours, now: tuesdayNoon), isFalse);
    });

    test('الوقت الحالي داخل نطاق العمل → true', () {
      final hours = [
        const MerchantBusinessHours(
          dayOfWeek: 2,
          openTime: '09:00',
          closeTime: '18:00',
          isClosed: false,
        ),
      ];
      expect(MerchantOpenStatus.isOpenNow(hours, now: tuesdayNoon), isTrue);
    });

    test('الوقت الحالي قبل الفتح → false', () {
      final hours = [
        const MerchantBusinessHours(
          dayOfWeek: 2,
          openTime: '14:00',
          closeTime: '18:00',
          isClosed: false,
        ),
      ];
      expect(MerchantOpenStatus.isOpenNow(hours, now: tuesdayNoon), isFalse);
    });

    test('الوقت الحالي بعد الإغلاق → false', () {
      final hours = [
        const MerchantBusinessHours(
          dayOfWeek: 2,
          openTime: '08:00',
          closeTime: '11:00',
          isClosed: false,
        ),
      ];
      expect(MerchantOpenStatus.isOpenNow(hours, now: tuesdayNoon), isFalse);
    });

    test('ساعات تمتد لما بعد منتصف الليل (غير مدعومة V1) → null', () {
      final hours = [
        const MerchantBusinessHours(
          dayOfWeek: 2,
          openTime: '22:00',
          closeTime: '02:00',
          isClosed: false,
        ),
      ];
      expect(MerchantOpenStatus.isOpenNow(hours, now: tuesdayNoon), isNull);
    });
  });
}
