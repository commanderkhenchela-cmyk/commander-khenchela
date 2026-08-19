import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/main.dart';

void main() {
  testWidgets('يعرض شاشة الترحيب مع اسم التطبيق وزر البدء', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CommanderKhenchelaApp());

    expect(find.text('كوموندور خنشلة'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
  });
}
