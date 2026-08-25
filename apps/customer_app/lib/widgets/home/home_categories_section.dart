import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/merchant_category.dart';
import '../../utils/merchant_category_icon.dart';
import '../category_chip.dart';

/// قسم التصنيفات المختصر في الصفحة الرئيسية: شرائح أفقية محدودة العدد
/// (بدل شبكة كبيرة ثابتة) + شريحة "عرض الكل" تفتح AllCategoriesScreen
/// لعرض كل التصنيفات في شبكة كاملة.
class HomeCategoriesSection extends StatelessWidget {
  static const int _visibleCount = 8;

  final String title;
  final List<MerchantCategory> categories;
  final Map<String, int> counts;
  final ValueChanged<MerchantCategory> onTapCategory;
  final VoidCallback onSeeAll;

  const HomeCategoriesSection({
    super.key,
    required this.title,
    required this.categories,
    required this.counts,
    required this.onTapCategory,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = categories.take(_visibleCount).toList();
    final hasMore = categories.length > _visibleCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(AppLocalizations.of(context).seeAllAction),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: visible.length + (hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  return SeeAllCategoriesChip(onTap: onSeeAll);
                }
                final category = visible[index];
                return CategoryChip(
                  icon: MerchantCategoryIcon.iconFor(category),
                  color: MerchantCategoryIcon.colorFor(category.id),
                  label: category.name,
                  onTap: () => onTapCategory(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
