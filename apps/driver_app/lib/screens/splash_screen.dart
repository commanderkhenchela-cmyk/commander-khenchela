import 'dart:async';

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
  // يُسجَّل مباشرةً وبشكل متزامن هنا فـ initState — قبل أول رسم إطار
  // بالضرورة — فتكتمل هذه المهمة حتمًا مرة واحدة عند اكتمال ذلك الإطار،
  // بغضّ النظر عن طول أي انتظار شبكة لاحق فـ _decideNextScreen (راجع
  // تعليقها). لو سجَّلنا addPostFrameCallback مباشرة هناك بدل هذا (كما
  // فـ محاولة أولى)، فبعد await شبكي حقيقي (fetchOwnDriver) يكون الإطار
  // الأول قد اكتمل واستُهلك بالفعل، ولا ضمان لرسم إطار جديد بعده يستدعي
  // callback مُسجَّل متأخرًا — تعليق دائم محتمل لكل موصّل مسجَّل دخوله.
  final _firstFrameDone = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_firstFrameDone.isCompleted) _firstFrameDone.complete();
    });
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

    // تأجيل التنقّل لما بعد اكتمال أول إطار (بدل استدعاء pushReplacement
    // فورًا) — لمستخدم غير مسجَّل دخوله تحديدًا، هذه الدالة تصل لهذه
    // النقطة شبه فوريًا (بلا أي await قبلها)، فقد يسبق حتى انتهاء أول
    // Route Transition الذي يُنشئه Flutter تلقائيًا عند بدء التطبيق —
    // تصادم داخلي معروف يسبّب استثناء '!navigator._debugLocked' فـ بعض
    // نسخ Flutter. _firstFrameDone (مسجَّل سلفًا فـ initState، راجع
    // تعليقه) يضمن اكتمال ذلك أولًا دائمًا، حتى بعد await شبكي طويل.
    await _firstFrameDone.future;
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
