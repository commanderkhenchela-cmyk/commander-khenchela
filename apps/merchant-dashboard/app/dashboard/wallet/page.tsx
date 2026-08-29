import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import type { WalletTransaction } from "@/lib/types";
import { WALLET_TRANSACTION_LABELS } from "@/lib/types";

/**
 * محفظة التاجر — قراءة فقط (لا زر إيداع/خصم هنا، هذه صلاحية الإدارة
 * حصرًا عبر admin_wallet_topup/admin_wallet_deduct). لا Payment Gateway
 * بعد — الدفع يتم بالكامل في المكتب، والإدارة تسجّله يدويًا.
 */
export default async function WalletPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();
  const { data: transactions } = await supabase
    .from("wallet_transactions")
    .select("id, type, amount, note, order_id, created_at")
    .eq("merchant_id", merchant.id)
    .order("created_at", { ascending: false });

  const all = (transactions ?? []) as WalletTransaction[];
  const balance = all.reduce((sum, t) => sum + Number(t.amount), 0);

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">محفظتي</h1>
      <p className="text-sm text-black/50 mb-6">
        لا توجد بوابة دفع إلكترونية بعد — لتعبئة رصيدك، ادفع المبلغ في
        مكتب الإدارة وسيُسجَّل هنا مباشرة. تُخصَم عمولة كل طلب تلقائيًا
        فور تسليمه للعميل.
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-6">
        <p className="text-sm text-black/60 mb-1">الرصيد الحالي</p>
        <p
          className={`text-3xl font-bold ${
            balance < 0 ? "text-error" : "text-primary"
          }`}
        >
          {balance.toFixed(2)} دج
        </p>
      </div>

      <p className="font-semibold mb-3">سجلّ الحركات</p>
      {all.length === 0 ? (
        <p className="text-sm text-black/50">لا توجد حركات مسجَّلة بعد.</p>
      ) : (
        <div className="grid gap-2">
          {all.map((t) => (
            <div
              key={t.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-3"
            >
              <div className="min-w-0">
                <p className="font-medium text-sm">
                  {WALLET_TRANSACTION_LABELS[t.type]}
                </p>
                {t.note && (
                  <p className="text-xs text-black/50 truncate">{t.note}</p>
                )}
                <p className="text-xs text-black/40 mt-0.5">
                  {new Date(t.created_at).toLocaleString("ar-DZ")}
                </p>
              </div>
              <span
                className={`shrink-0 font-semibold text-sm ${
                  t.amount >= 0 ? "text-primary" : "text-error"
                }`}
              >
                {t.amount >= 0 ? "+" : ""}
                {t.amount.toFixed(2)} دج
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
