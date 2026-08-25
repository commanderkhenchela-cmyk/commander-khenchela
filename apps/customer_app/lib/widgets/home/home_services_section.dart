import 'package:flutter/material.dart';

import '../../models/service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/service_icon.dart';
import '../pressable_scale.dart';

/// شبكة الخدمات الأعلى مستوى (تسوّق/مطاعم/طاكسي...) — ثابتة أعلى
/// الصفحة (قبل الأقسام الديناميكية القابلة لإعادة الترتيب)، تمامًا مثل
/// شبكات الخدمات في تطبيقات الـSuper Apps العالمية. الخدمة enabled من
/// الإدارة لكن غير مبنية فعليًا في التطبيق (راجع builtSlugs) تظهر باهتة
/// وتفتح ورقة "قريبًا" بدل شاشة غير موجودة — القرار يبقى بيد الشاشة
/// الأم (HomeScreen) عبر builtSlugs، هذا المكوّن لا يفترض شيئًا بنفسه.
class HomeServicesSection extends StatelessWidget {
  final List<AppService> services;
  final Set<String> builtSlugs;
  final ValueChanged<AppService> onTap;

  const HomeServicesSection({
    super.key,
    required this.services,
    required this.builtSlugs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: services.length,
          separatorBuilder: (context, index) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceTile(
              service: service,
              isBuilt: builtSlugs.contains(service.slug),
              onTap: () => onTap(service),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final AppService service;
  final bool isBuilt;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.isBuilt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = isBuilt ? 1.0 : 0.55;

    return SizedBox(
      width: 72,
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    ServiceIcon.iconFor(service.slug),
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: Text(
                    service.name,
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
      ),
    );
  }
}
