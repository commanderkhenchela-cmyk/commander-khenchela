import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:customer_app/main.dart';
import 'package:customer_app/services/locale_controller.dart';
import 'package:customer_app/services/theme_controller.dart';

void main() {
  testWidgets('ينتقل من شاشة البداية مباشرة لقائمة المحلات (لا شاشة ترحيب وسيطة)', (
    WidgetTester tester,
  ) async {
    // CommanderKhenchelaApp تقرأ ThemeController وLocaleController عبر
    // Provider (نفس ما يوفّره main() فعليًا قبل runApp) — بدونهما يفشل
    // build() بصمت هنا في الاختبار.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController(),
          ),
          ChangeNotifierProvider<LocaleController>(
            create: (_) => LocaleController(),
          ),
        ],
        child: const CommanderKhenchelaApp(),
      ),
    );

    // شاشة البداية تظهر أولًا (تحمل اسم التطبيق أيضًا)
    expect(find.text('كوموندي خنشلة'), findsOneWidget);

    // ننتظر مدة عرض شاشة البداية (حد أدنى ~1.1 ثانية + حركة الشعار +
    // تحميل الهوية/التواصل) قبل الانتقال — راجع splash_screen.dart.
    // شاشة الترحيب/تأكيد الولاية محذوفتان نهائيًا من التدفّق: الانتقال
    // يذهب مباشرة لقائمة المحلات (HomeScreen).
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('كوموندي خنشلة'), findsOneWidget);
    // أيقونة الإشعارات فـ AppBar — موجودة حصريًا فـ HomeScreen، لا فـ
    // شاشة البداية — تأكيد أننا وصلنا فعليًا لـHomeScreen.
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });
}
