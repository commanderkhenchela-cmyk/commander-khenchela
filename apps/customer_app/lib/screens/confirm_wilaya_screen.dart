import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'home_screen.dart';

/// V1 يعمل في ولاية خنشلة فقط. بدل قائمة بلديات طويلة (21 بلدية) منذ أول
/// خطوة، نكتفي بشاشة تأكيد بسيطة — نضيف اختيار البلدية تدريجيًا لاحقًا
/// عند الحاجة الفعلية (مثلاً عند إدخال عنوان التوصيل في الـ Checkout).
const String _prefsWilayaConfirmedKey = 'wilaya_confirmed';

/// شاشة تأكيد الولاية — الخطوة الثانية في رحلة العميل بعد الترحيب.
class ConfirmWilayaScreen extends StatelessWidget {
  const ConfirmWilayaScreen({super.key});

  Future<void> _onContinue(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsWilayaConfirmedKey, true);

    if (!context.mounted) return;
    final wilayaName = AppLocalizations.of(context).wilayaName;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(locationName: wilayaName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.location_on_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.inWilayaMessage(l10n.wilayaName),
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.wilayaCoverageMessage(l10n.wilayaName),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _onContinue(context),
                  child: Text(l10n.continueAction),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
