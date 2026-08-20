import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'notifications_screen.dart';

/// شاشة "حسابي" — نقطة الدخول لتسجيل الدخول أو إدارة الحساب.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _login() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignedIn = AuthService.isSignedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isSignedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AuthService.currentUser?.userMetadata?['full_name']
                              as String? ??
                          'مرحبًا بك',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyOrdersScreen(),
                          ),
                        );
                      },
                      child: const Text('طلباتي'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                      child: const Text('إشعاراتي'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _logout,
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'سجّل الدخول لمتابعة طلباتك',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('تسجيل الدخول / إنشاء حساب'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
