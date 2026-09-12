import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';

/// تذييل "تحميل المزيد" موحَّد لكل قوائم Pagination الحقيقية فـ التطبيق
/// (my_orders_screen وأخواتها الثلاث، merchants_screen، search_screen) —
/// زر عادي، أو مؤشر تحميل، أو رسالة خطأ + إعادة محاولة للصفحة الفاشلة
/// فقط (لا يُعاد تحميل ما سبق نجاحه). كانت هذه بالحرف 6 نسخ خاصة مستقلة
/// (_LoadMoreFooter في 5 شاشات، _LoadMoreControl في search_screen) بنفس
/// التصميم تمامًا — هذه هي النسخة المشتركة الآن.
class LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const LoadMoreFooter({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Column(
            children: [
              Text(
                l10n.loadMoreError,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(onPressed: onTap, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(l10n.loadMoreAction),
        ),
      ),
    );
  }
}
