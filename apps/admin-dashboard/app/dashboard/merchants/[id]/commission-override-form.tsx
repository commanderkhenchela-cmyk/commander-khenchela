"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * تعديل نسبة عمولة هذا التاجر تحديدًا — تحديث مباشر على العمود (لا RPC
 * جديدة)، لأن الحارس الفعلي هنا هو Trigger فـ القاعدة
 * (merchants_protect_commission_override) الذي يرفض أي تعديل على هذا
 * العمود تحديدًا لمن لا يملك settings.manage، بغضّ النظر عن هذه
 * الواجهة — نفس نمط الحماية العمودية المُثبَت أصلًا على drivers.status.
 */
export default function CommissionOverrideForm({
  merchantId,
  currentOverride,
  defaultRate,
}: {
  merchantId: string;
  currentOverride: number | null;
  defaultRate: string;
}) {
  const router = useRouter();
  const [value, setValue] = useState(
    currentOverride === null ? "" : String(currentOverride),
  );
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function save(newOverride: number | null) {
    setLoading(true);
    setError(null);
    setSaved(false);

    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ commission_rate_override: newOverride })
      .eq("id", merchantId);

    if (error) {
      setError("تعذّر الحفظ.");
      setLoading(false);
      return;
    }

    setSaved(true);
    router.refresh();
    setLoading(false);
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (value.trim() === "") {
      save(null);
      return;
    }
    const rate = Number(value);
    if (isNaN(rate) || rate < 0 || rate > 100) {
      setError("أدخل نسبة بين 0 و100، أو اتركها فارغة لاستخدام النسبة العامة.");
      return;
    }
    save(rate);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2">
      <div className="flex items-end gap-2">
        <div className="flex-1">
          <label className="block text-sm font-medium mb-1">
            نسبة عمولة خاصة (%)
          </label>
          <input
            type="number"
            min={0}
            max={100}
            step="0.01"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder={`فارغ = النسبة العامة (${defaultRate}%)`}
            className="w-full rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
          />
        </div>
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          حفظ
        </button>
        {currentOverride !== null && (
          <button
            type="button"
            disabled={loading}
            onClick={() => {
              setValue("");
              save(null);
            }}
            className="rounded-lg border border-border px-4 py-2.5 text-sm disabled:opacity-60"
          >
            إلغاء الاستثناء
          </button>
        )}
      </div>
      {error && <p className="text-error text-xs">{error}</p>}
      {saved && !error && <p className="text-primary text-xs">تم الحفظ</p>}
    </form>
  );
}
