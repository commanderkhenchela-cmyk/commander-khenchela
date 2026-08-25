import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import 'pressable_scale.dart';

/// بطاقة تصنيف واحدة داخل شبكة التصنيفات — Component مستقل وقابل لإعادة
/// الاستخدام (وللاختبار المباشر، راجع category_grid_tile_test.dart) بدل
/// أن يكون مدفونًا كـ widget خاص داخل شاشة واحدة.
///
/// الأيقونة داخل دائرة ملوَّنة، الاسم بحد أقصى سطرين مع Ellipsis عند
/// الطول الزائد، والعدد أسفله بخط أصغر وأخفت. مصمَّمة لتعمل ضمن ارتفاع
/// بطاقة ثابت (mainAxisExtent) في الشبكة الأب — راجع تعليق Overflow في
/// merchant_categories_screen.dart لسبب عدم استخدام aspectRatio هنا.
class CategoryGridTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final VoidCallback onTap;

  const CategoryGridTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.pillAll,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillAll,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.pillAll,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                // العدد يظهر فقط عند وجود محل واحد فعلي على الأقل — لا نملأ
                // كل بطاقة فارغة بكلمة "قريبًا" مكرَّرة (كانت هذه الصيغة
                // القديمة سبب الشكوى الصريحة بأن الشبكة "تبدو ميتة").
                // بطاقة بلا عدّاد سطر ثانٍ تبقى مفهومة تمامًا: الاسم
                // والأيقونة وحدهما كافيان، والمساحة الفارغة أهدأ بصريًا من
                // نص متكرر بلا معنى فعلي.
                const SizedBox(height: 2),
                Text(
                  count > 0
                      ? AppLocalizations.of(context).storeCountLabel(count)
                      : ' ',
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
