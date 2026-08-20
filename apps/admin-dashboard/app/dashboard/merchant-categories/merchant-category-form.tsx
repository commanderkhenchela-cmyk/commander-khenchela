"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function MerchantCategoryForm({
  nextSortOrder,
}: {
  nextSortOrder: number;
}) {
  const router = useRouter();
  const [icon, setIcon] = useState("🛍️");
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error } = await supabase.from("merchant_categories").insert({
      name,
      icon: icon.trim() || "🛍️",
      sort_order: nextSortOrder,
    });

    if (error) {
      setError("تعذّر إضافة التصنيف.");
      setLoading(false);
      return;
    }

    setName("");
    setIcon("🛍️");
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <input
        type="text"
        value={icon}
        onChange={(e) => setIcon(e.target.value)}
        placeholder="🍔"
        maxLength={4}
        className="w-16 rounded-lg border border-border px-2 py-2.5 text-center text-lg outline-none focus:border-primary"
      />
      <input
        type="text"
        required
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="مثال: مطاعم"
        className="flex-1 rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
      />
      <button
        type="submit"
        disabled={loading}
        className="rounded-lg bg-primary text-white font-semibold px-4 disabled:opacity-60"
      >
        إضافة
      </button>
      {error && <p className="text-error text-sm">{error}</p>}
    </form>
  );
}
