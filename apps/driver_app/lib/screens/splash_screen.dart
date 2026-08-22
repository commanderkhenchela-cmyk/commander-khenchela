import 'package:flutter/material.dart';

import '../models/driver.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'pending_screen.dart';
import 'rejected_screen.dart';

/// نقطة الدخول الوحيدة لقرار "أين يذهب الموصّل" — كل شاشة تُغيّر حالة
/// الحساب (تسجيل دخول/خروج، إرسال onboarding، تحديث حالة الاعتماد)
/// تعود إلى هذه الشاشة عبر pushReplacement بدل أن تحفظ كل شاشة منطق
/// التوجيه بنفسها، مطابق لمنطق getMerchantContext + صفحة التوجيه
/// الجذرية في لوحة التاجر (app/page.tsx)، لكن بأسلوب Flutter/Navigator.
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
    Widget next;

    if (!AuthService.isSignedIn) {
      next = const LoginScreen();
    } else {
      Driver? driver;
      try {
        driver = await DriverService.fetchOwnDriver();
      } catch (_) {
        // تعذّر الاتصال بالسيرفر — نعرض شاشة الدخول مع خيار إعادة
        // المحاولة، بدل تعليق الشاشة إلى الأبد.
        driver = null;
      }

      if (driver == null) {
        next = const OnboardingScreen();
      } else if (driver.isPending) {
        next = const PendingScreen();
      } else if (driver.isRejected) {
        next = const RejectedScreen();
      } else {
        next = const HomeScreen();
      }
    }

    if (!mounted) return;

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pedal_bike_rounded, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Commander Khenchela — الموصّل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
