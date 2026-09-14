"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * تسجيل دفعة نقدية استلمها المكتب من الموصّل — نسخة حرفية من
 * WalletTopupForm (merchants/[id]/wallet-topup-form.tsx)، فقط
 * driverId/admin_driver_wallet_* بدل merchantId/admin_wallet_*.
 */
export default function DriverWalletTopupForm({
  driverId,
  kind,
}: {
  driverId: string;
  kind: "topup" | "deduction";
}) {
  const router = useRouter();
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  const isTopup = kind === "topup";
  const rpcName = isTopup ? "admin_driver_wallet_topup" : "admin_driver_wallet_deduct";

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
      p_driver_id: driverId,
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
