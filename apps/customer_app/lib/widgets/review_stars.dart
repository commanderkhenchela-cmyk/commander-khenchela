import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// صف من 5 نجوم — للعرض فقط (تقييم محفوظ بالفعل) أو للاختيار التفاعلي
/// إن مُرِّر onChanged (حوار إضافة تقييم جديد في OrderDetailScreen).
///
/// كانت أيقونات مجرّدة بلا أي تسمية صوتية — قارئ الشاشة لا يعرف قيمة
/// التقييم المعروض، ولا أي نجمة بالضبط سيضغط عليها فـ وضع الاختيار.
/// الآن: عرض القراءة فقط = عقدة Semantics واحدة تلخّص القيمة، والاختيار
/// التفاعلي = كل نجمة زر Semantics مستقل بتسمية قيمته (راجع
/// rateStarsAction/ratingValueLabel فـ l10n).
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
    final l10n = AppLocalizations.of(context);

    final row = Row(
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

        return Semantics(
          button: true,
          selected: filled,
          label: l10n.rateStarsAction(starValue),
          child: InkWell(
            onTap: () => onChanged!(starValue),
            borderRadius: BorderRadius.circular(size),
            child: Padding(padding: const EdgeInsets.all(2), child: icon),
          ),
        );
      }),
    );

    if (onChanged != null) return row;

    return Semantics(
      label: l10n.ratingValueLabel(rating),
      excludeSemantics: true,
      child: row,
    );
  }
}
