import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/widgets/merchant_logo.dart';

void main() {
  testWidgets('يعرض الأيقونة الاحتياطية عند غياب رابط الصورة', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MerchantLogo(url: null, size: 56, iconSize: 28),
        ),
      ),
    );

    expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('يحاول عرض صورة الشبكة عند وجود رابط', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MerchantLogo(
            url: 'https://example.com/logo.png',
            size: 56,
            iconSize: 28,
          ),
        ),
      ),
    );

    // لا ننتظر اكتمال تحميل الشبكة (لا اتصال فعلي في الاختبار) — يكفي
    // التأكد أن Widget حاول عرض Image.network بدل الأيقونة الاحتياطية.
    expect(find.byType(Image), findsOneWidget);
  });
}
