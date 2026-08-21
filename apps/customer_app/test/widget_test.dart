import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:customer_app/main.dart';
import 'package:customer_app/services/theme_controller.dart';

void main() {
  testWidgets('يعرض شاشة الترحيب مع اسم التطبيق وزر البدء بعد شاشة البداية', (
    WidgetTester tester,
  ) async {
    // بدون عنوان مؤكَّد مسبقًا → SplashScreen يوجّه لشاشة الترحيب
    SharedPreferences.setMockInitialValues({});

    // CommanderKhenchelaApp تقرأ ThemeController عبر Provider (نفس ما يوفّره
    // main() فعليًا قبل runApp) — بدونه يفشل build() بصمت هنا في الاختبار.
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>(
        create: (_) => ThemeController(),
        child: const CommanderKhenchelaApp(),
      ),
    );

    // شاشة البداية تظهر أولًا (تحمل اسم التطبيق أيضًا)
    expect(find.text('كوموندور خنشلة'), findsOneWidget);

    // ننتظر مدة عرض شاشة البداية (3 ثوانٍ) قبل الانتقال لشاشة الترحيب
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('كوموندور خنشلة'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
  });
}
