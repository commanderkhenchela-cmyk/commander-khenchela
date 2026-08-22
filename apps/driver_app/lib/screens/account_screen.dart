import 'package:flutter/material.dart';

import '../models/driver.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import 'splash_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Driver?> _future;

  @override
  void initState() {
    super.initState();
    _future = DriverService.fetchOwnDriver();
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: FutureBuilder<Driver?>(
        future: _future,
        builder: (context, snapshot) {
          final driver = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (driver != null) ...[
                Text(
                  driver.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  driver.phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.pedal_bike_rounded, size: 18),
                    label: const Text('دراجة'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              OutlinedButton(
                onPressed: _logout,
                child: const Text('تسجيل الخروج'),
              ),
            ],
          );
        },
      ),
    );
  }
}
