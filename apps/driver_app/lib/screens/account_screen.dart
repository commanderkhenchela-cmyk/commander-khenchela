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
                    avatar: Icon(_vehicleIcon(driver.vehicleType), size: 18),
                    label: Text(_vehicleLabel(driver.vehicleType)),
                  ),
                ),
                // تقييم السائق (rating_avg/rating_count) — محسوب تلقائيًا
                // من driver_reviews (راجع migration driver_reviews)، لا
                // يظهر إطلاقًا قبل أول تقييم حقيقي (نفس فلسفة RatingBadge
                // فـ customer_app: لا "0.0" وهمية لسائق بلا تقييمات بعد).
                if (driver.ratingCount > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xFFF5A623),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${driver.ratingAvg.toStringAsFixed(1)} '
                          '(${driver.ratingCount} تقييم)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
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

/// نفس نمط DRIVER_VEHICLE_TYPE_ICONS/LABELS فـ admin-dashboard
/// (lib/types.ts) — استُبدل بها الشارة الثابتة "دراجة" التي كانت تُعرض
/// دائمًا بغضّ النظر عن vehicle_type الفعلي (راجع migration
/// 20260910000000_driver_vehicle_types).
IconData _vehicleIcon(String vehicleType) {
  switch (vehicleType) {
    case 'car':
      return Icons.local_taxi_outlined;
    case 'truck':
      return Icons.local_shipping_outlined;
    default:
      return Icons.pedal_bike_rounded;
  }
}

String _vehicleLabel(String vehicleType) {
  switch (vehicleType) {
    case 'car':
      return 'طاكسي';
    case 'truck':
      return 'شاحنة';
    default:
      return 'دراجة';
  }
}
