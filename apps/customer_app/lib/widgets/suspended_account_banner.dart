import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../screens/support_screen.dart';
import '../services/auth_service.dart';

/// شريط تنبيه دائم يظهر أعلى الرئيسية إذا كان حساب العميل موقوفًا
/// (users.is_suspended) — الحماية الفعلية موجودة أصلًا فـ كل RPC إنشاء
/// طلب عبر التطبيق (راجع migration 20260831000000_fraud_system
/// وتوابعها فـ create_order/create_delivery_request/create_ride_request/
/// create_craftsman_request/driver_claim_order)، هذا الشريط فقط يجعل
/// الحالة *مفهومة* للمستخدم بدل أن يكتشفها بالصدفة عند فشل أول محاولة
/// طلب برسالة عامة (راجع أيضًا accountSuspendedError المُستخدَمة فـ كل
/// _friendlyError/_friendlyOrderError عبر شاشات الطلب الأربع).
///
/// مستقل تمامًا عن تحميل بقية الرئيسية (نفس فلسفة قسم "بالقرب منك" —
/// راجع تعليق _HomeScreenState.initState فـ home_screen.dart): فشل هذا
/// الاستعلام أو تأخّره لا يوقف أو يؤخر أي شيء آخر بالصفحة، فقط لا يظهر
/// الشريط.
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
      // تجاهل بصمت — نفس فلسفة ContactService.load(): فشل هذا الفحص
      // لا يمنع استخدام بقية التطبيق أبدًا. الحماية الفعلية (RPC) تبقى
      // قائمة بغضّ النظر عن نجاح هذا الشريط أو فشله.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuspended) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
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
                  l10n.accountSuspendedTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: errorColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.accountSuspendedMessage,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: errorColor,
                    side: BorderSide(color: errorColor),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                  child: Text(l10n.contactUsTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
