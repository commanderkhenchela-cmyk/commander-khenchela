import 'package:flutter/material.dart';

import '../services/branding_service.dart';
import '../widgets/app_logo.dart';
import 'confirm_wilaya_screen.dart';

/// شاشة الترحيب الأولى — بسيطة جدًا، بدون خيارات كثيرة، وفق مبدأ
/// "أقل عدد ممكن من الخطوات" و"عدم إغراق المستخدم بالخيارات".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const AppLogo(size: 96),
              const SizedBox(height: 24),
              Text(
                BrandingService.appName,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'اطلب من محلات خنشلة، ووصّلها لباب دارك',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ConfirmWilayaScreen(),
                      ),
                    );
                  },
                  child: const Text('ابدأ'),
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
