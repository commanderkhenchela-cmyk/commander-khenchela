import 'package:flutter/material.dart';

/// صف من 5 نجوم — للعرض فقط (تقييم محفوظ بالفعل) أو للاختيار التفاعلي
/// إن مُرِّر onChanged (حوار إضافة تقييم جديد في OrderDetailScreen).
class ReviewStars extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  const ReviewStars({
    super.key,
    required this.rating,
    this.size = 24,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= rating;
        final icon = Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: const Color(0xFFF5A623),
        );

        if (onChanged == null) return icon;

        return InkWell(
          onTap: () => onChanged!(starValue),
          borderRadius: BorderRadius.circular(size),
          child: Padding(padding: const EdgeInsets.all(2), child: icon),
        );
      }),
    );
  }
}
