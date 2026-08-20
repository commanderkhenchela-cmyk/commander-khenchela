"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function CategoryForm() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error } = await supabase.from("categories").insert({ name });

    if (error) {
      setError("تعذّر إضافة التصنيف.");
      setLoading(false);
      return;
    }

    setName("");
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <input
        type="text"
        required
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="مثال: مواد غذائية"
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
