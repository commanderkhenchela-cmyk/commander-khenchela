"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function AdActions({
  adId,
  isActive,
  title,
}: {
  adId: string;
  isActive: boolean;
  title: string;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function toggleActive() {
    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("advertisements")
      .update({ is_active: !isActive })
      .eq("id", adId);
    router.refresh();
    setLoading(false);
  }

  async function remove() {
    if (!confirm(`حذف إعلان "${title}" نهائيًا؟`)) return;

    setLoading(true);
    const supabase = createClient();
    await supabase.from("advertisements").delete().eq("id", adId);
    router.refresh();
    setLoading(false);
  }

  return (
    <div className="flex flex-col items-end gap-1 shrink-0">
      <button
        onClick={toggleActive}
        disabled={loading}
        className={`text-xs font-semibold px-2.5 py-1 rounded-full disabled:opacity-50 ${
          isActive
            ? "bg-primary/10 text-primary"
            : "bg-black/5 text-black/50"
        }`}
      >
        {isActive ? "نشط" : "معطَّل"}
      </button>
      <button
        onClick={remove}
        disabled={loading}
        className="text-xs text-error disabled:opacity-50"
      >
        حذف
      </button>
    </div>
  );
}
