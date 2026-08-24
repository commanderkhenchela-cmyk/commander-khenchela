import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/branding_service.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

const String _prefsWilayaConfirmedKey = 'wilaya_confirmed';
const String _wilayaName = 'خنشلة';

/// شاشة البداية — تُعرض لحظة فتح التطبيق، وتقرّر أين يذهب المستخدم:
/// - أول مرة يفتح فيها التطبيق → شاشة الترحيب (Welcome)
/// - سبق أن أكّد ولايته من قبل → مباشرة لقائمة المحلات، بدون تكرار نفس
///   خطوات الإعداد في كل مرة يفتح فيها التطبيق.
///
/// لا "انتظار مصطنع" هنا: التحميل الثقيل الفعلي (هوية التطبيق، الإعدادات،
/// اتصال Supabase) يحدث بالكامل في main() *قبل* ظهور هذه الشاشة أصلًا —
/// العمل الحقيقي المتبقي هنا هو فقط قراءة تفضيل محلي (SharedPreferences)،
/// شبه فوري دائمًا. المدة الوحيدة المضبوطة هي حد أدنى صغير لعرض الشعار
/// (احترافية العلامة، نفس ما تفعله كل تطبيقات الـSuper Apps العالمية)،
/// وليست انتظارًا ثابتًا بمعزل عن حالة التحميل الفعلية — إن انتهى العمل
/// الحقيقي أبكر، ينتقل التطبيق بمجرد اكتمال حركة الشعار فقط، لا أكثر.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minDisplayDuration = Duration(milliseconds: 1100);

  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Fade + Scale ناعمان للشعار (curve مرن قليلًا يعطي إحساس "استقرار"
    // بدل ظهور مفاجئ) — النص يتبع بتأخير بسيط بعده مباشرة، حركة واحدة
    // متسلسلة بدل عدة حركات متزامنة تُشعر المستخدم بالفوضى.
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
    _decideNextScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decideNextScreen() async {
    final started = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final wilayaConfirmed = prefs.getBool(_prefsWilayaConfirmedKey) ?? false;

    final elapsed = DateTime.now().difference(started);
    final remaining = _minDisplayDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => wilayaConfirmed
            ? const HomeScreen(locationName: _wilayaName)
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
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: AppLogo(
                      size: 96,
                      backgroundColor: Colors.white,
                      iconColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      Text(
                        BrandingService.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(context).appTagline,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _textFade,
                  child: const _LoadingIndicator(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// مؤشر تحميل صغير جدًا وأنيق أسفل شاشة البداية — دائري رفيع بدل نص
/// "Loading..." وحيد، بلا أي مبالغة (نفس فلسفة الطلب: Premium لا Flashy).
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(
              Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context).loading,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
