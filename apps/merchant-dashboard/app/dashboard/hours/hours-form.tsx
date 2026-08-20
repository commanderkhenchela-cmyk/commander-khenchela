"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DAY_NAMES, type MerchantBusinessHours } from "@/lib/types";

interface DayRow {
  dayOfWeek: number;
  isClosed: boolean;
  openTime: string;
  closeTime: string;
}

function buildInitialRows(initialHours: MerchantBusinessHours[]): DayRow[] {
  return Array.from({ length: 7 }, (_, dayOfWeek) => {
    const existing = initialHours.find((h) => h.day_of_week === dayOfWeek);
    return {
      dayOfWeek,
      isClosed: existing?.is_closed ?? false,
      openTime: existing?.open_time?.slice(0, 5) ?? "09:00",
      closeTime: existing?.close_time?.slice(0, 5) ?? "18:00",
    };
  });
}

export default function HoursForm({
  merchantId,
  initialHours,
}: {
  merchantId: string;
  initialHours: MerchantBusinessHours[];
}) {
  const router = useRouter();
  const [rows, setRows] = useState<DayRow[]>(() =>
    buildInitialRows(initialHours),
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  function updateRow(dayOfWeek: number, patch: Partial<DayRow>) {
    setSaved(false);
    setRows((prev) =>
      prev.map((r) => (r.dayOfWeek === dayOfWeek ? { ...r, ...patch } : r)),
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const invalidRow = rows.find(
      (r) => !r.isClosed && r.openTime >= r.closeTime,
    );
    if (invalidRow) {
      setError(
        `وقت الفتح يجب أن يكون قبل وقت الإغلاق — تحقق من يوم ${DAY_NAMES[invalidRow.dayOfWeek]}.`,
      );
      return;
    }

    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.from("merchant_business_hours").upsert(
      rows.map((r) => ({
        merchant_id: merchantId,
        day_of_week: r.dayOfWeek,
        is_closed: r.isClosed,
        open_time: r.isClosed ? null : r.openTime,
        close_time: r.isClosed ? null : r.closeTime,
      })),
      { onConflict: "merchant_id,day_of_week" },
    );

    if (error) {
      setError("تعذّر حفظ ساعات العمل.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setLoading(false);
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3">
      {rows.map((row) => (
        <div
          key={row.dayOfWeek}
          className="rounded-xl border border-border bg-card p-4 flex items-center gap-3 flex-wrap"
        >
          <span className="font-medium w-20 shrink-0">
            {DAY_NAMES[row.dayOfWeek]}
          </span>

          <label className="flex items-center gap-1.5 text-sm text-black/60">
            <input
              type="checkbox"
              checked={row.isClosed}
              onChange={(e) =>
                updateRow(row.dayOfWeek, { isClosed: e.target.checked })
              }
            />
            مغلق
          </label>

          {!row.isClosed && (
            <div className="flex items-center gap-2 mr-auto">
              <input
                type="time"
                value={row.openTime}
                onChange={(e) =>
                  updateRow(row.dayOfWeek, { openTime: e.target.value })
                }
                className="rounded-lg border border-border px-2 py-1.5 text-sm outline-none focus:border-primary"
              />
              <span className="text-black/40 text-sm">إلى</span>
              <input
                type="time"
                value={row.closeTime}
                onChange={(e) =>
                  updateRow(row.dayOfWeek, { closeTime: e.target.value })
                }
                className="rounded-lg border border-border px-2 py-1.5 text-sm outline-none focus:border-primary"
              />
            </div>
          )}
        </div>
      ))}

      {error && <p className="text-error text-sm">{error}</p>}
      {saved && <p className="text-primary text-sm">تم الحفظ بنجاح.</p>}

      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-lg bg-primary text-white font-semibold py-3 mt-2 disabled:opacity-60"
      >
        {loading ? "جارٍ الحفظ..." : "حفظ ساعات العمل"}
      </button>
    </form>
  );
}
