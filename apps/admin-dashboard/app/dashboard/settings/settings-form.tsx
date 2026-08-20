"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function SettingsForm({
  settingKey,
  currentValue,
  unit,
}: {
  settingKey: string;
  currentValue: string;
  unit?: string;
}) {
  const router = useRouter();
  const [value, setValue] = useState(currentValue);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const supabase = createClient();
    const { error } = await supabase.rpc("admin_set_setting", {
      p_key: settingKey,
      p_value: value,
    });

    if (error) {
      setError("تعذّر حفظ الإعداد.");
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
        <input
          type="number"
          step="0.01"
          min={0}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>
      {unit && <span className="text-black/60 pb-2.5">{unit}</span>}
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
