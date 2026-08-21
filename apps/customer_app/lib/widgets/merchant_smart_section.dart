import 'package:flutter/material.dart';

import '../models/merchant.dart';
import 'merchant_mini_card.dart';

/// قسم أفقي قابل للتمرير لعرض مجموعة محلات (مميزة / الأكثر طلبًا / مفتوح
/// الآن / بالقرب منك / أُضيفت حديثًا...). Component عام — يُستخدم داخل
/// شاشة تصنيف واحد (MerchantsScreen) وداخل الصفحة الرئيسية (HomeScreen)
/// على حد سواء، بنفس المظهر. العنوان نص حر (title) بدل ثابت داخل الكود،
/// لأنه في الصفحة الرئيسية يأتي من إعدادات لوحة الإدارة (home_sections)
/// — الأدمن يستطيع تغييره متى شاء دون أي تعديل كود.
///
/// لا يعرض نفسه أبدًا فارغًا: على المستدعي فحص merchants.isEmpty قبل بناء
/// هذا الـ Widget أصلًا (نفس القاعدة المتّبعة في كل أقسام التطبيق الذكية).
class MerchantSmartSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Merchant> merchants;
  final ValueChanged<Merchant> onTapMerchant;

  const MerchantSmartSection({
    super.key,
    required this.title,
    required this.icon,
    required this.merchants,
    required this.onTapMerchant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
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
              ],
            ),
          ),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: merchants.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return MerchantMiniCard(
                  merchant: merchant,
                  onTap: () => onTapMerchant(merchant),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
