import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/branding_service.dart';
import '../services/contact_service.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';

/// شاشة البداية — تُعرض لحظة فتح التطبيق، ثم تنتقل مباشرة لقائمة المحلات
/// (لا شاشة ترحيب/تأكيد ولاية وسيطة — طُلب حذفهما نهائيًا من التدفّق،
/// V1 يعمل فـ خنشلة فقط أصلًا فلا معنى حقيقي لخطوة "تأكيد" لا تُغيّر شيئًا).
///
/// هذه الشاشة تحمل العمل الحقيقي فعليًا — هوية التطبيق (BrandingService)
/// وبيانات التواصل (ContactService) تُحمَّلان هنا (شبكة، حتى 4 ثوانٍ لكل
/// واحدة). شريط التقدّم 0%→100% أسفل الشعار (طلب صريح من المستخدم) مربوط
/// بمدة عرض ثابتة 5 ثوانٍ (_minDisplayDuration) — نفس مدة العلامة
/// التجارية، لا أكثر ولا أقل فـ الحالة العادية. **صدق العرض محفوظ**: لو
/// التحميل الحقيقي انتهى قبل 5 ثوانٍ، الشريط يكمّل طبيعيًا لـ100% مع
/// نهاية الـ5 ثوانٍ (لا قفزة مفاجئة)؛ لو تأخّرت الشبكة فعليًا لأكثر من
/// 5 ثوانٍ (حالة نادرة)، الشريط يتوقّف عند 99% (لا يكذب بـ100% وهمية)
/// حتى يكتمل التحميل الحقيقي فعلًا، ثم يقفز لـ100% قبل الانتقال مباشرة.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _minDisplayDuration = Duration(seconds: 5);

  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;

  // شريط التقدّم 0%→100% — مؤقِّت منفصل عن حركة الشعار (900ms)، يمتد
  // على كامل مدة العرض الدنيا (5 ثوانٍ) ليعكس تقدّمًا مقروءًا وواقعيًا،
  // لا حركة سريعة منتهية خلال أقل من ثانية.
  late final AnimationController _progressController;
  late final Animation<double> _progress;

  bool _dataReady = false;

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

    _progressController = AnimationController(
      vsync: this,
      duration: _minDisplayDuration,
    );
    _progress = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();
    _progressController.forward();
    _decideNextScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _decideNextScreen() async {
    final started = DateTime.now();

    // العمل الحقيقي بالتوازي: هوية التطبيق + بيانات التواصل (شبكة) —
    // معًا لا بالتتابع، حتى لا نجمع مهلتيهما (4+4 ثوانٍ) بدل الأسوأ
    // بينهما فقط. نفس نمط (a, b).wait المستخدَم فعليًا فـ
    // ride_detail_screen.dart.
    await (BrandingService.load(), ContactService.load()).wait;
    if (mounted) setState(() => _dataReady = true);

    final elapsed = DateTime.now().difference(started);
    final remaining = _minDisplayDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (routeContext) =>
            HomeScreen(locationName: AppLocalizations.of(routeContext).wilayaName),
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
          animation: Listenable.merge([_controller, _progressController]),
          builder: (context, child) {
            // صدق العرض: لا نكشف 100% إلا فعلًا جاهزين للانتقال — لو
            // الشريط وصل نهايته قبل اكتمال التحميل الحقيقي (شبكة بطيئة)،
            // يتوقّف عند 99% بدل قفزة وهمية لـ100%.
            final progressValue = _dataReady
                ? _progress.value
                : _progress.value.clamp(0.0, 0.99);

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
                  child: _LoadingIndicator(progress: progressValue),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// شريط تقدّم 0%→100% أسفل شاشة البداية — رفيع وأنيق، مع نسبة رقمية
/// (Tabular Figures حتى لا "يهتزّ" عرض الرقم مع تغيّره) بدل مؤشّر دائري
/// مجرّد، طلب صريح من المستخدم لتحميل مقروء وملموس.
class _LoadingIndicator extends StatelessWidget {
  final double progress;

  const _LoadingIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      children: [
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
