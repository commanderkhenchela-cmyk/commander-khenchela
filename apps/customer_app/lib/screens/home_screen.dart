import 'package:flutter/material.dart';

/// شاشة رئيسية مؤقتة (Placeholder) — تظهر بعد اختيار البلدية.
/// سيتم استبدالها لاحقًا بشاشة تصفح التصنيفات والمحلات الحقيقية.
class HomeScreen extends StatelessWidget {
  final String locationName;

  const HomeScreen({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('كوموندور خنشلة')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'تم اختيار بلديتك: $locationName',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'قريبًا: تصفح التصنيفات والمحلات هنا',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
