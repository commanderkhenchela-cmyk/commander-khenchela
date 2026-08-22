import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'splash_screen.dart';

/// حساب الموصّل بانتظار موافقة الإدارة — نفس مفهوم شاشة "pending" في
/// لوحة التاجر، لكن كشاشة Flutter بزر "تحديث" يدوي بدل استماع لحظي
/// (تفاديًا للتعقيد؛ المستخدم يفتح التطبيق لاحقًا فيُعاد فحص الحالة
/// تلقائيًا في splash_screen على أي حال).
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  void _refresh(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    _refresh(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'حسابك قيد المراجعة',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'سيراجع فريق الإدارة بياناتك قريبًا. ستصلك إشعار فور '
                'الموافقة على حسابك.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _refresh(context),
                child: const Text('تحديث'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _logout(context),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
