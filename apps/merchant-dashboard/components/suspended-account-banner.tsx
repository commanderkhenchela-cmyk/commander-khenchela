/**
 * شريط تنبيه دائم فوق كل صفحات لوحة التاجر إذا كان حسابه موقوفًا
 * (users.is_suspended — راجع migration 20260831000000_fraud_system
 * و20260909000000). لا تفاعل هنا (server component بسيط، بلا "use
 * client") — الحماية الفعلية موجودة أصلًا فـ RLS/triggers، هذا فقط
 * يمنع التاجر من الظنّ أن حسابه يعمل بشكل طبيعي بينما محاولاته لتأكيد/
 * رفض/تجهيز أي طلب سترفضها القاعدة صامتًا لولا هذا التنبيه.
 */
export function SuspendedAccountBanner({
  isSuspended,
}: {
  isSuspended: boolean;
}) {
  if (!isSuspended) return null;

  return (
    <div className="bg-error/10 border-b border-error/30 px-4 py-2.5 text-sm text-error font-medium text-center">
      حسابك موقوف — لا يمكنك تأكيد أو تجهيز أي طلب حاليًا. تواصل مع الإدارة
      لمعرفة السبب.
    </div>
  );
}
