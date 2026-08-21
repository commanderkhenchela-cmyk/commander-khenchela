import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';
import 'services/branding_service.dart';
import 'services/cart_service.dart';
import 'services/contact_service.dart';
import 'services/favorites_controller.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final themeController = ThemeController();

  // تُحمَّل هوية التطبيق (الاسم/الشعار/الألوان، قابلة للتعديل من لوحة
  // الإدارة) وتفضيل الوضع الداكن المحفوظ قبل أول رسم للواجهة، حتى لا
  // "تقفز" الألوان أو الثيم لاحقًا.
  await Future.wait([
    BrandingService.load(),
    ContactService.load(),
    themeController.load(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider(create: (_) => FavoritesController()),
      ],
      child: const CommanderKhenchelaApp(),
    ),
  );
}

class CommanderKhenchelaApp extends StatelessWidget {
  const CommanderKhenchelaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: BrandingService.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        primaryColor: BrandingService.primaryColor,
        errorColor: BrandingService.errorColor,
      ),
      darkTheme: AppTheme.dark(
        primaryColor: BrandingService.primaryColor,
        errorColor: BrandingService.errorColor,
      ),
      themeMode: themeController.mode,

      // دعم اللغة العربية واتجاه RTL منذ البداية (Arabic-first)
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(),
    );
  }
}
