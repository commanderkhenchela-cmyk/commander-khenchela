"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DAY_NAMES, type MerchantBusinessHours } from "@/lib/types";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Checkbox, FieldError, FieldSuccess, Input } from "@/components/ui/input";

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
        <Card key={row.dayOfWeek} padding="p-4" className="flex items-center gap-3 flex-wrap">
          <span className="font-medium w-20 shrink-0">{DAY_NAMES[row.dayOfWeek]}</span>

          <Checkbox
            id={`closed-${row.dayOfWeek}`}
            label="مغلق"
            checked={row.isClosed}
            onChange={(e) => updateRow(row.dayOfWeek, { isClosed: e.target.checked })}
          />

          {!row.isClosed && (
            <div className="flex items-center gap-2 mr-auto">
              <Input
                type="time"
                value={row.openTime}
                onChange={(e) => updateRow(row.dayOfWeek, { openTime: e.target.value })}
                className="w-auto py-1.5 text-sm"
              />
              <span className="text-black/40 text-sm">إلى</span>
              <Input
                type="time"
                value={row.closeTime}
                onChange={(e) => updateRow(row.dayOfWeek, { closeTime: e.target.value })}
                className="w-auto py-1.5 text-sm"
              />
            </div>
          )}
        </Card>
      ))}

      <FieldError>{error}</FieldError>
      <FieldSuccess>{saved && "تم الحفظ بنجاح."}</FieldSuccess>

      <Button type="submit" disabled={loading} className="w-full mt-2">
        {loading ? "جارٍ الحفظ..." : "حفظ ساعات العمل"}
      </Button>
    </form>
  );
}
