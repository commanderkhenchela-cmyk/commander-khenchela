import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/widgets/category_grid_tile.dart';

/// اختبار مباشر لإصلاح مشكلة "BOTTOM OVERFLOWED" في بطاقة التصنيف:
/// نضع أطول أسماء تصنيفات حقيقية موجودة فعليًا في المشروع داخل نفس
/// الشبكة (mainAxisExtent: 152، 3 أعمدة) التي تستخدمها
/// MerchantCategoriesScreen، تحت حجم خط نظام كبير جدًا (2.0x و3.0x)،
/// ونتأكد أن Flutter لم يُبلّغ عن أي RenderFlex overflow. هذا هو نفس
/// السيناريو الذي سبّب المشكلة الأصلية (خط نظام كبير + اسم تصنيف طويل).
void main() {
  const longNames = [
    'بقالة ومواد غذائية',
    'المخابز والحلويات',
    'الملابس والأزياء',
    'الجمال والعناية',
    'الصحة والصيدليات',
    'مشروبات ومقاهي',
  ];

  Future<void> pumpGrid(WidgetTester tester, double textScale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 152,
            ),
            itemCount: longNames.length,
            itemBuilder: (context, index) => CategoryGridTile(
              icon: Icons.storefront_rounded,
              color: Colors.teal,
              label: longNames[index],
              count: 0,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'لا يظهر أي Overflow مع أطول أسماء التصنيفات بحجم خط نظام مضاعف (2x)',
    (tester) async {
      await pumpGrid(tester, 2.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'لا يظهر أي Overflow حتى مع حجم خط نظام كبير جدًا (3x) لإعدادات إمكانية الوصول',
    (tester) async {
      await pumpGrid(tester, 3.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('اسم التصنيف الطويل يُقصّ بثلاث نقاط بدل كسر التصميم', (
    tester,
  ) async {
    await pumpGrid(tester, 1.0);
    final textWidget = tester.widget<Text>(
      find.text('بقالة ومواد غذائية').first,
    );
    expect(textWidget.maxLines, 2);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
