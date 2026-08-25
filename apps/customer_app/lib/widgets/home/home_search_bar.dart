import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/design_tokens.dart';

/// شريط بحث "زخرفي" أعلى الصفحة الرئيسية — لا يحرّر النص هنا مباشرة، بل
/// ينقل فورًا إلى SearchScreen (نفس نمط تطبيقات التجارة الكبرى: شريط
/// البحث الرئيسي واجهة تنقّل لا حقل تحرير مستقل). RTL كامل تلقائيًا من
/// اتجاه التطبيق العام، فلا حاجة لأي عكس يدوي هنا.
class HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const HomeSearchBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).searchHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
