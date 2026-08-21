import 'package:flutter/material.dart';

/// شارة تقييم صغيرة (نجمة + الرقم + عدد التقييمات بين قوسين) — تُستخدم
/// داخل بطاقة المحل. لا تُبنى هذه الشارة أبدًا إلا بعد تأكّد المستدعي أن
/// merchant.hasRating صحيح (راجع تعليق الحقل في نموذج Merchant) — لا
/// نعرض "0.0" وهميًا لمحل بلا تقييمات بعد.
class RatingBadge extends StatelessWidget {
  final double ratingAvg;
  final int ratingCount;

  const RatingBadge({
    super.key,
    required this.ratingAvg,
    required this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
        const SizedBox(width: 2),
        Text(
          ratingAvg.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '($ratingCount)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
