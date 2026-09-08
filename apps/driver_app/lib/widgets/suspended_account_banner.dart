import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// شريط تنبيه دائم يظهر أعلى الرئيسية إذا كان حساب الموصّل موقوفًا
/// (users.is_suspended) — الحماية الفعلية موجودة أصلًا فـ
/// driver_claim_order/driver_accept_delivery_request/driver_accept_ride
/// (راجع migration 20260831000000_fraud_system وتوابعها)، هذا الشريط
/// فقط يجعل الحالة *مفهومة* للموصّل بدل أن يكتشفها بالصدفة عند فشل أول
/// محاولة استلام طلب. نفس فلسفة customer_app/widgets/
/// suspended_account_banner.dart بالحرف، بلا l10n (driver_app لا يستخدم
/// AppLocalizations — نصوص عربية ثابتة كبقية شاشات هذا التطبيق).
class SuspendedAccountBanner extends StatefulWidget {
  const SuspendedAccountBanner({super.key});

  @override
  State<SuspendedAccountBanner> createState() =>
      _SuspendedAccountBannerState();
}

class _SuspendedAccountBannerState extends State<SuspendedAccountBanner> {
  bool _isSuspended = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!AuthService.isSignedIn) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('is_suspended')
          .eq('id', AuthService.currentUser!.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (mounted && row != null && row['is_suspended'] == true) {
        setState(() => _isSuspended = true);
      }
    } catch (_) {
      // تجاهل بصمت — فشل هذا الفحص لا يمنع استخدام بقية التطبيق أبدًا.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuspended) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_rounded, color: errorColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حسابك موقوف',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: errorColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'لا يمكنك حاليًا استلام طلبات جديدة. تواصل مع الإدارة '
                  'لمعرفة السبب.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
