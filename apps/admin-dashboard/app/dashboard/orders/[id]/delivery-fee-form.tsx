"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function DeliveryFeeForm({
  orderId,
  currentFee,
}: {
  orderId: string;
  currentFee: number;
}) {
  const router = useRouter();
  const [fee, setFee] = useState(String(currentFee));
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const feeValue = Number(fee);
    if (isNaN(feeValue) || feeValue < 0) {
      setError("قيمة غير صالحة.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error } = await supabase.rpc("admin_set_delivery_fee", {
      p_order_id: orderId,
      p_fee: feeValue,
    });

    if (error) {
      setError("تعذّر تحديث رسوم التوصيل.");
      setLoading(false);
      return;
    }

    setSaved(true);
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-end gap-2">
      <div className="flex-1">
        <label className="block text-sm font-medium mb-1">
          رسوم التوصيل (دج)
        </label>
        <input
          type="number"
          min={0}
          step="0.01"
          value={fee}
          onChange={(e) => setFee(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>
      <button
        type="submit"
        disabled={loading}
        className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
      >
        حفظ
      </button>
      {error && <p className="text-error text-sm">{error}</p>}
      {saved && !error && <p className="text-primary text-sm">تم الحفظ</p>}
    </form>
  );
}
