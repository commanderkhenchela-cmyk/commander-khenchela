import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/models/merchant.dart';
import 'package:customer_app/models/merchant_business_hours.dart';

/// اختبارات أولوية Manual Override على ساعات العمل (migration
/// 20260904000000). التحقق الزمني الدقيق لحساب "داخل/خارج الدوام"
/// نفسه مغطّى بالكامل في merchant_open_status_test.dart (عبر حقن now
/// صراحةً) — هذا الملف يركّز فقط على قرار Merchant.isOpenNow: متى
/// يُستشار ساعات العمل ومتى يتجاوزها التبديل اليدوي كليًا، بلا اعتماد
/// على الوقت الحقيقي للجهاز (deterministic بالكامل).
void main() {
  const withinHours = [
    MerchantBusinessHours(
      dayOfWeek: 2,
      openTime: '09:00',
      closeTime: '18:00',
      isClosed: false,
    ),
  ];

  const outsideHours = [
    MerchantBusinessHours(
      dayOfWeek: 2,
      openTime: '09:00',
      closeTime: '10:00',
      isClosed: false,
    ),
  ];

  Merchant buildMerchant({
    required List<MerchantBusinessHours> businessHours,
    required bool isManuallyOpen,
    DateTime? statusOverriddenAt,
  }) {
    return Merchant(
      id: 'm1',
      storeName: 'محل اختباري',
      businessHours: businessHours,
      isManuallyOpen: isManuallyOpen,
      statusOverriddenAt: statusOverriddenAt,
    );
  }

  group('Merchant.isOpenNow — بلا Manual Override إطلاقًا (statusOverriddenAt=null)', () {
    test('لا ساعات عمل محفوظة → null (لا تخمين)', () {
      final merchant = buildMerchant(businessHours: const [], isManuallyOpen: true);
      expect(merchant.isOpenNow, isNull);
    });
  });

  group('Merchant.isOpenNow — Manual Override نشِط (statusOverriddenAt != null): أولوية مطلقة', () {
    final overriddenAt = DateTime(2026, 8, 25, 11, 0);

    test('التاجر فتح يدويًا رغم أن ساعات العمل تقول "مغلق الآن" → true (الأولوية للتبديل اليدوي)', () {
      final merchant = buildMerchant(
        businessHours: outsideHours,
        isManuallyOpen: true,
        statusOverriddenAt: overriddenAt,
      );
      expect(merchant.isOpenNow, isTrue);
    });

    test('التاجر أغلق يدويًا رغم أن ساعات العمل تقول "مفتوح الآن" → false (الأولوية للتبديل اليدوي)', () {
      final merchant = buildMerchant(
        businessHours: withinHours,
        isManuallyOpen: false,
        statusOverriddenAt: overriddenAt,
      );
      expect(merchant.isOpenNow, isFalse);
    });

    test('التاجر فتح يدويًا ولا يملك أي ساعات عمل محفوظة → true (لا يبقى مخفيًا)', () {
      final merchant = buildMerchant(
        businessHours: const [],
        isManuallyOpen: true,
        statusOverriddenAt: overriddenAt,
      );
      expect(merchant.isOpenNow, isTrue);
    });

    test('التاجر أغلق يدويًا ولا يملك أي ساعات عمل محفوظة → false', () {
      final merchant = buildMerchant(
        businessHours: const [],
        isManuallyOpen: false,
        statusOverriddenAt: overriddenAt,
      );
      expect(merchant.isOpenNow, isFalse);
    });
  });

  group('Merchant.fromMap', () {
    test('يقرأ is_open وstatus_overridden_at من الصفّ بشكل صحيح', () {
      final merchant = Merchant.fromMap({
        'id': 'm1',
        'store_name': 'محل',
        'is_open': false,
        'status_overridden_at': '2026-08-25T11:00:00.000Z',
      });
      expect(merchant.isManuallyOpen, isFalse);
      expect(merchant.statusOverriddenAt, isNotNull);
    });

    test('status_overridden_at غائب من الصفّ → null (توافق مع بيانات قديمة قبل هذه الترقية)', () {
      final merchant = Merchant.fromMap({
        'id': 'm1',
        'store_name': 'محل',
        'is_open': true,
      });
      expect(merchant.statusOverriddenAt, isNull);
    });
  });
}
