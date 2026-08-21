import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/widgets/review_stars.dart';

void main() {
  testWidgets('يملأ عدد النجوم بحسب التقييم فقط', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReviewStars(rating: 3))),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
  });

  testWidgets('يستدعي onChanged بالقيمة الصحيحة عند الضغط على نجمة', (
    tester,
  ) async {
    int? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewStars(rating: 1, onChanged: (value) => tapped = value),
        ),
      ),
    );

    // النجوم الخمسة بترتيب واحد إلى خمسة — نضغط الرابعة.
    await tester.tap(find.byType(InkWell).at(3));
    expect(tapped, 4);
  });
}
