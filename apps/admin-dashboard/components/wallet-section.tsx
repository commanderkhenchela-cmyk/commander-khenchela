import type { WalletTransactionType } from "@/lib/types";
import WalletTopupForm from "@/components/wallet-topup-form";

/**
 * قسم "محفظة" كامل (رصيد + وصف + إيداع/خصم + سجلّ حركات) — نفس البنية
 * المستخدَمة بالحرف فـ merchants/[id]/page.tsx وdrivers/[id]/page.tsx
 * (كانتا مكرَّرتين تمامًا، الفرق فقط العنوان/الوصف/أسماء الـRPC وخريطة
 * التسميات)، موحَّدة هنا فـ مكوّن واحد. النوع البنيوي لـ transaction
 * يكفي فيه الحقول المعروضة فعليًا (type/amount/note/created_at) — كلا
 * WalletTransaction وDriverWalletTransaction يطابقانه تلقائيًا (بلا
 * Generics)، رغم اختلاف حقولهما المرجعية الإضافية غير المعروضة هنا.
 */
export default function WalletSection({
  title,
  description,
  entityIdParamName,
  entityId,
  topupRpc,
  deductRpc,
  canManageWallet,
  transactions,
  balance,
  labels,
}: {
  title: string;
  description: string;
  entityIdParamName: string;
  entityId: string;
  topupRpc: string;
  deductRpc: string;
  canManageWallet: boolean;
  transactions: {
    id: string;
    type: WalletTransactionType;
    amount: number;
    note: string | null;
    created_at: string;
  }[];
  balance: number;
  labels: Record<WalletTransactionType, string>;
}) {
  return (
    <div className="rounded-xl border border-border bg-card p-5 mb-4">
      <div className="flex items-center justify-between mb-3">
        <p className="font-semibold">{title}</p>
        <span
          className={`text-lg font-bold ${
            balance < 0 ? "text-error" : "text-primary"
          }`}
        >
          {balance.toFixed(2)} دج
        </span>
      </div>
      <p className="text-xs text-black/50 mb-3">{description}</p>

      {canManageWallet && (
        <div className="grid gap-2 mb-4 sm:grid-cols-2">
          <WalletTopupForm
            entityIdParamName={entityIdParamName}
            entityId={entityId}
            kind="topup"
            topupRpc={topupRpc}
            deductRpc={deductRpc}
          />
          <WalletTopupForm
            entityIdParamName={entityIdParamName}
            entityId={entityId}
            kind="deduction"
            topupRpc={topupRpc}
            deductRpc={deductRpc}
          />
        </div>
      )}

      {transactions.length === 0 ? (
        <p className="text-sm text-black/50">لا توجد حركات مسجَّلة بعد.</p>
      ) : (
        <div className="grid gap-2">
          {transactions.map((t) => (
            <div
              key={t.id}
              className="flex items-center justify-between gap-3 text-sm border-b border-border last:border-b-0 pb-2 last:pb-0"
            >
              <div className="min-w-0">
                <p className="font-medium">{labels[t.type]}</p>
                {t.note && (
                  <p className="text-xs text-black/50 truncate">{t.note}</p>
                )}
                <p className="text-xs text-black/40">
                  {new Date(t.created_at).toLocaleString("ar-DZ")}
                </p>
              </div>
              <span
                className={`shrink-0 font-semibold ${
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
