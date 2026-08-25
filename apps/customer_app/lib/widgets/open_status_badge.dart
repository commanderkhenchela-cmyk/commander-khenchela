import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// شارة صغيرة "مفتوح الآن" / "مغلق الآن" — تُستخدم في بطاقات المحل
/// (العمودية والأفقية). لا تُعرض أبدًا إلا عندما تُعرَف الحالة فعليًا
/// (merchant.isOpenNow != null من طرف الشاشة المستدعية)، أبدًا كتخمين.
class OpenStatusBadge extends StatelessWidget {
  final bool isOpen;

  const OpenStatusBadge({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOpen ? theme.colorScheme.primary : Colors.grey.shade600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          isOpen
              ? AppLocalizations.of(context).openNowSectionTitle
              : AppLocalizations.of(context).closedNowLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
