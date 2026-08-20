import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/branding_service.dart';
import '../widgets/app_logo.dart';
import 'merchants_screen.dart';
import 'welcome_screen.dart';

const String _prefsWilayaConfirmedKey = 'wilaya_confirmed';
const String _wilayaName = 'خنشلة';

/// شاشة البداية — تُعرض لحظة فتح التطبيق، وتقرّر أين يذهب المستخدم:
/// - أول مرة يفتح فيها التطبيق → شاشة الترحيب (Welcome)
/// - سبق أن أكّد ولايته من قبل → مباشرة لقائمة المحلات، بدون تكرار نفس
///   خطوات الإعداد في كل مرة يفتح فيها التطبيق (كانت هذه القيمة تُحفظ
///   في ConfirmWilayaScreen لكن لا أحد كان يقرأها — تصحيح فعلي لخلل تنقّل).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNextScreen();
  }

  Future<void> _decideNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final wilayaConfirmed = prefs.getBool(_prefsWilayaConfirmedKey) ?? false;

    // 3 ثوانٍ كاملة لعرض الشعار (طلب صريح) — يكفي أيضًا لتحميل هوية
    // التطبيق (BrandingService/ContactService) في main() قبل هذه الشاشة.
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => wilayaConfirmed
            ? const MerchantsScreen(locationName: _wilayaName)
            : const WelcomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(
              size: 96,
              backgroundColor: Colors.white,
              iconColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              BrandingService.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
