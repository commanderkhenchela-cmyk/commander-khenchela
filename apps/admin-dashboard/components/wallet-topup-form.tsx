"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * تسجيل دفعة نقدية استلمها المكتب من صاحب المحفظة (تاجر أو موصّل) —
 * نفس نمط DeliveryFeeForm (RPC واحدة محكومة، لا UPDATE مباشر على أي
 * رصيد). type="topup" وtype="deduction" مشتركان فـ نفس المكوّن لتفادي
 * تكرار شبه كامل — الفرق فقط اسم الدالة والنص والألوان.
 *
 * مُوحَّد من نسختين شبه متطابقتين (merchants/[id]/wallet-topup-form.tsx
 * وdrivers/[id]/driver-wallet-topup-form.tsx، commit 5e4e07e) — الفرق
 * الوحيد بينهما كان اسم بارامتر المعرّف واسما الـRPC، الآن معطيات هنا.
 */
export default function WalletTopupForm({
  entityIdParamName,
  entityId,
  kind,
  topupRpc,
  deductRpc,
}: {
  /** اسم بارامتر معرّف صاحب المحفظة فـ الـRPC — "p_merchant_id" أو "p_driver_id". */
  entityIdParamName: string;
  entityId: string;
  kind: "topup" | "deduction";
  topupRpc: string;
  deductRpc: string;
}) {
  const router = useRouter();
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  const isTopup = kind === "topup";
  const rpcName = isTopup ? topupRpc : deductRpc;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const amountValue = Number(amount);
    if (isNaN(amountValue) || amountValue <= 0) {
      setError("أدخل مبلغًا صحيحًا أكبر من صفر.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error } = await supabase.rpc(rpcName, {
      [entityIdParamName]: entityId,
      p_amount: amountValue,
      p_note: note || null,
    });

    if (error) {
      setError(error.message || "تعذّر تنفيذ العملية.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setAmount("");
    setNote("");
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2">
      <div className="flex gap-2">
        <input
          type="number"
          min={0.01}
          step="0.01"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="المبلغ (دج)"
          className="flex-1 rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
        />
        <button
          type="submit"
          disabled={loading}
          className={`shrink-0 rounded-lg px-4 py-2 text-sm font-semibold text-white disabled:opacity-60 ${
            isTopup ? "bg-primary" : "bg-error"
          }`}
        >
          {isTopup ? "تسجيل إيداع" : "تسجيل خصم"}
        </button>
      </div>
      <input
        type="text"
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder={isTopup ? "ملاحظة (اختياري)" : "سبب الخصم (يُنصح بذكره)"}
        className="rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
      />
      {error && <p className="text-error text-xs">{error}</p>}
      {saved && !error && <p className="text-primary text-xs">تم التسجيل</p>}
    </form>
  );
}
