import 'package:flutter/material.dart';

import '../utils/navigation_launcher.dart';

/// زر "التنقّل" الموحَّد فـ كل شاشات تفاصيل المهام (طلبات/رحلات/طلبات
/// عامة) — يفتح خرائط جوجل بتوجيه حيّ نحو الوجهة المُمرَّرة. يظهر فقط
/// حين توجد وجهة فعلية (إحداثيات أو نص عنوان)، ولا يفشل بصمت — رسالة
/// واضحة إن تعذّر فتح تطبيق الخرائط (نادر، مثل جهاز بلا أي تطبيق خرائط
/// مثبَّت إطلاقًا).
class NavigateButton extends StatelessWidget {
  final String label;
  final double? lat;
  final double? lng;
  final String? fallbackAddressText;

  const NavigateButton({
    super.key,
    required this.label,
    required this.lat,
    required this.lng,
    this.fallbackAddressText,
  });

  @override
  Widget build(BuildContext context) {
    final hasDestination =
        (lat != null && lng != null) ||
        (fallbackAddressText != null && fallbackAddressText!.trim().isNotEmpty);
    if (!hasDestination) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () async {
        final opened = await openNavigation(
          lat: lat,
          lng: lng,
          fallbackAddressText: fallbackAddressText,
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر فتح تطبيق الخرائط.')),
          );
        }
      },
      icon: const Icon(Icons.directions_rounded),
      label: Text(label),
    );
  }
}
