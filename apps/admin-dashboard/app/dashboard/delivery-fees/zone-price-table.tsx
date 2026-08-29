"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { DeliveryFeeZonePrice } from "@/lib/types";

export default function ZonePriceTable({
  serviceId,
  communes,
  prices,
}: {
  serviceId: string;
  communes: { id: number; name: string }[];
  prices: DeliveryFeeZonePrice[];
}) {
  const router = useRouter();
  const [values, setValues] = useState<Record<number, string>>(() =>
    Object.fromEntries(prices.map((p) => [p.commune_id, String(p.price)])),
  );
  const [expanded, setExpanded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSave() {
    setLoading(true);
    setError(null);
    setSaved(false);

    const rows = Object.entries(values)
      .filter(([, v]) => v.trim() !== "")
      .map(([communeId, v]) => ({ commune_id: Number(communeId), price: Number(v) }));

    if (rows.length === 0) {
      setError("أدخل سعرًا لبلدية واحدة على الأقل.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error } = await supabase.rpc("admin_set_delivery_fee_zone_prices", {
      p_service_id: serviceId,
      p_prices: rows,
    });

    if (error) {
      setError(error.message || "تعذّر الحفظ.");
      setLoading(false);
      return;
    }

    setSaved(true);
    router.refresh();
    setLoading(false);
  }

  return (
    <div>
      <button
        type="button"
        onClick={() => setExpanded((v) => !v)}
        className="text-sm font-medium text-primary"
      >
        {expanded ? "إخفاء" : "عرض"} أسعار البلديات ({prices.length} مُسعَّرة)
      </button>

      {expanded && (
        <div className="mt-3">
          <div className="grid gap-1.5 max-h-64 overflow-y-auto pr-1">
            {communes.map((commune) => (
              <div key={commune.id} className="flex items-center justify-between gap-3">
                <span className="text-sm text-black/70 flex-1">{commune.name}</span>
                <input
                  type="number"
                  min={0}
                  step="0.01"
                  placeholder="—"
                  value={values[commune.id] ?? ""}
                  onChange={(e) =>
                    setValues((prev) => ({ ...prev, [commune.id]: e.target.value }))
                  }
                  className="w-24 rounded-lg border border-border px-2 py-1 text-sm outline-none focus:border-primary"
                />
              </div>
            ))}
          </div>
          <div className="flex items-center gap-3 mt-3">
            <button
              type="button"
              onClick={handleSave}
              disabled={loading}
              className="rounded-lg bg-primary text-white font-semibold px-4 py-1.5 text-sm disabled:opacity-60"
            >
              حفظ الأسعار
            </button>
            {error && <p className="text-error text-xs">{error}</p>}
            {saved && !error && <p className="text-primary text-xs">تم الحفظ</p>}
          </div>
        </div>
      )}
    </div>
  );
}
