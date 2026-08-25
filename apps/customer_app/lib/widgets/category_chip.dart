import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import 'pressable_scale.dart';

/// "شريحة" تصنيف صغيرة لقسم أفقي قابل للتمرير في الصفحة الرئيسية — بديل
/// مصغَّر عن CategoryGridTile (البطاقة الكبيرة في شبكة "كل التصنيفات").
/// نفس فلسفة منع الفيضان: الاسم داخل Expanded بحد أقصى سطرين.
class CategoryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 76,
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريحة "عرض الكل" في نهاية قسم التصنيفات الأفقي — نفس أبعاد
/// [CategoryChip] حتى يبقى المحاذاة الرأسية متّسقة داخل نفس الصف.
class SeeAllCategoriesChip extends StatelessWidget {
  final VoidCallback onTap;

  const SeeAllCategoriesChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 76,
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: Text(
                  AppLocalizations.of(context).seeAllAction,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
