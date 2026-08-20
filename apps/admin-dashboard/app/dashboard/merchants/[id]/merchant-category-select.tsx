"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { MerchantCategory } from "@/lib/types";

export default function MerchantCategorySelect({
  merchantId,
  categoryId,
  categories,
}: {
  merchantId: string;
  categoryId: string | null;
  categories: MerchantCategory[];
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const newCategoryId = e.target.value || null;
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ category_id: newCategoryId })
      .eq("id", merchantId);

    if (error) {
      setError("تعذّر تحديث تصنيف المحل.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  return (
    <div>
      <select
        defaultValue={categoryId ?? ""}
        onChange={handleChange}
        disabled={loading}
        className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary disabled:opacity-60"
      >
        <option value="">— بدون تصنيف —</option>
        {categories.map((c) => (
          <option key={c.id} value={c.id}>
            {c.icon} {c.name}
          </option>
        ))}
      </select>
      {!categoryId && (
        <p className="text-sm text-black/50 mt-2">
          هذا المحل لن يظهر ضمن أي تصنيف للعميل حتى تختار له تصنيفًا رئيسيًا.
        </p>
      )}
      {error && <p className="text-error text-sm mt-2">{error}</p>}
    </div>
  );
}
