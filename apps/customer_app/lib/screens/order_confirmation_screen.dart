import 'package:flutter/material.dart';

import 'my_orders_screen.dart';

/// شاشة تأكيد نجاح إرسال الطلب — رسالة نجاح واضحة، بدون تعقيد.
class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortId = orderId.substring(0, 8).toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'تم إرسال طلبك بنجاح! ✅',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'رقم الطلب: $shortId',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيراجع المحل طلبك قريبًا، وستصلك التحديثات هنا.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const MyOrdersScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text('عرض طلباتي'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).popUntil((route) => route.isFirst);
                },
                child: const Text('العودة للرئيسية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
