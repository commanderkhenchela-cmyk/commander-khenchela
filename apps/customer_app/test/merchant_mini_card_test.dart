import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/models/merchant.dart';
import 'package:customer_app/widgets/merchant_mini_card.dart';

/// نفس منهج اختبار Overflow المستخدَم في category_grid_tile_test.dart:
/// أسماء محلات طويلة داخل ارتفاع بطاقة ثابت (118، نفس ما تستخدمه
/// _SmartSection في merchants_screen.dart) وخط نظام مكبَّر، للتأكد أن
/// نفس مشكلة "BOTTOM OVERFLOWED" لا تتكرر في هذا القسم الجديد.
void main() {
  const longNames = [
    'مطعم الأصالة للمأكولات الشعبية التقليدية',
    'صيدلية النور الجديدة',
    'محل الخياطة والأزياء العصرية',
  ];

  Future<void> pumpRow(WidgetTester tester, double textScale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            height: 118,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: longNames.length,
              itemBuilder: (context, index) => MerchantMiniCard(
                merchant: Merchant(
                  id: 'id-$index',
                  storeName: longNames[index],
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('لا يظهر أي Overflow في بطاقة المحل المصغّرة بخط نظام 2x', (
    tester,
  ) async {
    await pumpRow(tester, 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('لا يظهر أي Overflow بخط نظام كبير جدًا (3x)', (tester) async {
    await pumpRow(tester, 3.0);
    expect(tester.takeException(), isNull);
  });
}
