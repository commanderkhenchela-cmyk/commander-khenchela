import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const CommanderKhenchelaApp());
}

class CommanderKhenchelaApp extends StatelessWidget {
  const CommanderKhenchelaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كوموندور خنشلة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),

      // دعم اللغة العربية واتجاه RTL منذ البداية (Arabic-first)
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const WelcomeScreen(),
    );
  }
}
