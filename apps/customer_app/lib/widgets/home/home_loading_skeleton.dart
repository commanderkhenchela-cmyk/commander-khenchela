import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// عرض Skeleton بسيط أثناء أول تحميل للصفحة الرئيسية — يعكس شكل الصفحة
/// القادمة تقريبًا (شريط بحث + بانر + صف شرائح + بطاقات أفقية) بدل
/// مؤشر تحميل وحيد.
class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    Widget block({required double height, EdgeInsets? margin}) => Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: base,
        borderRadius: AppRadius.cardAll,
      ),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        block(height: 52),
        const SizedBox(height: 16),
        block(height: 180),
        const SizedBox(height: 20),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: 76,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => Container(
              width: 128,
              decoration: BoxDecoration(
                color: base,
                borderRadius: AppRadius.cardAll,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
