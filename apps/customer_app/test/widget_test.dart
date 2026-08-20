import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:customer_app/main.dart';

void main() {
  testWidgets('يعرض شاشة الترحيب مع اسم التطبيق وزر البدء بعد شاشة البداية', (
    WidgetTester tester,
  ) async {
    // بدون عنوان مؤكَّد مسبقًا → SplashScreen يوجّه لشاشة الترحيب
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CommanderKhenchelaApp());

    // شاشة البداية تظهر أولًا (تحمل اسم التطبيق أيضًا)
    expect(find.text('كوموندور خنشلة'), findsOneWidget);

    // ننتظر مدة العرض القصيرة للانتقال لشاشة الترحيب
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('كوموندور خنشلة'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
  });
}
