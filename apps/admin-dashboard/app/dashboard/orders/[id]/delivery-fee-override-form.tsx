"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * تعديل استثنائي على رسم توصيل مُحسَّب أصلًا تلقائيًا — يستبدل
 * DeliveryFeeForm القديم (كان "تحديد" الرسم يدويًا لكل طلب دائمًا؛
 * أصبح الآن محسوبًا تلقائيًا، وهذا فقط تجاوز نادر). السبب إلزامي —
 * يُسجَّل تلقائيًا فـ سجل النشاطات (admin_activity_log) عبر
 * admin_override_delivery_fee، لا كود تسجيل هنا.
 */
export default function DeliveryFeeOverrideForm({
  orderId,
  currentFee,
}: {
  orderId: string;
  currentFee: number;
}) {
  const router = useRouter();
  const [fee, setFee] = useState(String(currentFee));
  const [reason, setReason] = useState("");
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
    if (reason.trim() === "") {
      setError("يجب ذكر سبب التعديل.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error } = await supabase.rpc("admin_override_delivery_fee", {
      p_order_id: orderId,
      p_new_fee: feeValue,
      p_reason: reason.trim(),
    });

    if (error) {
      setError(error.message || "تعذّر تحديث رسوم التوصيل.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setReason("");
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2">
      <div className="flex items-end gap-2">
        <div className="flex-1">
          <label className="block text-sm font-medium mb-1">
            رسوم التوصيل الجديدة (دج)
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
          حفظ التعديل
        </button>
      </div>
      <input
        type="text"
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="سبب التعديل (إلزامي)"
        className="rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
      />
      {error && <p className="text-error text-sm">{error}</p>}
      {saved && !error && <p className="text-primary text-sm">تم الحفظ</p>}
    </form>
  );
}
