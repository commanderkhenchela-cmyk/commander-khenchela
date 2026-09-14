import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigation.dart';
import 'config/supabase_config.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/branding_service.dart';
import 'services/cart_service.dart';
import 'services/favorites_controller.dart';
import 'services/locale_controller.dart';
import 'services/push_notification_service.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final themeController = ThemeController();
  final localeController = LocaleController();

  // تفضيلا الوضع الداكن واللغة يُحمَّلان قبل أول رسم للواجهة — قراءتان
  // محليّتان فوريتان (SharedPreferences، لا شبكة)، حتى لا "تقفز" الألوان
  // أو اللغة لاحقًا.
  //
  // BrandingService/ContactService (شبكة، حتى 4 ثوانٍ لكل واحدة) انتقلا
  // عمدًا لـ SplashScreen نفسها (راجع _decideNextScreen هناك) — بدل
  // انتظارهما هنا قبل ظهور أي شيء على الشاشة (شاشة بيضاء/سوداء فارغة
  // فعليًا أثناء الانتظار، رغم وجود شاشة بداية مصمَّمة بعناية جاهزة).
  // الآن: الشاشة المُصمَّمة تظهر فورًا، ومؤشّر التحميل عليها يعكس عملًا
  // حقيقيًا قيد التنفيذ لا انتظارًا صوريًا ثابتًا. الضمان نفسه محفوظ:
  // SplashScreen تنتظر اكتمال التحميلين قبل الانتقال، فلا تُبنى
  // HomeScreen (تستهلك BrandingService) قبل اكتمالهما.
  await Future.wait([themeController.load(), localeController.load()]);

  // إشعارات Push (PHASE 11) — لا تُنتظَر أبدًا قبل أول رسم للواجهة (قد
  // تستغرق ثوانٍ بسبب حوار إذن النظام)، وتفشل بهدوء بالكامل إن لم يكن
  // مشروع Firebase مربوطًا بعد (راجع تعليق الخدمة نفسها).
  unawaited(PushNotificationService.initialize());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<LocaleController>.value(value: localeController),
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
    final localeController = context.watch<LocaleController>();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
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

      // العربية افتراضيًا وقابلة للتبديل الآن (شاشة الإعدادات) — راجع
      // LocaleController. الفرنسية/الإنجليزية مفعَّلتان فعليًا (ملفا
      // app_fr.arb/app_en.arb موجودان بنفس المفاتيح)، لكن بعدد نصوص
      // محدود حاليًا مقارنة بالعربية — راجع تقرير الفحص لتفاصيل النطاق
      // المتبقي. RTL/LTR يتبعان الـLocale تلقائيًا من Flutter نفسه، بلا
      // أي كود إضافي مطلوب هنا.
      locale: localeController.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(),
    );
  }
}
