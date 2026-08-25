import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:customer_app/l10n/app_localizations.dart';
import 'package:customer_app/services/favorites_controller.dart';
import 'package:customer_app/widgets/favorite_button.dart';

void main() {
  testWidgets('يعرض قلبًا فارغًا افتراضيًا (لا مفضّلة، لا Supabase مهيَّأة)', (
    tester,
  ) async {
    // FavoritesController يبني نفسه بأمان حتى بدون Supabase.initialize()
    // في بيئة الاختبار (راجع try/catch في المُنشئ) — يبقى خاملًا بمجموعة
    // فارغة بدل رمي استثناء يُسقط الاختبار.
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesController>(
        create: (_) => FavoritesController(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FavoriteButton(merchantId: 'm1')),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });
}
