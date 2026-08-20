"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Merchant } from "@/lib/types";

export default function SettingsForm({ merchant }: { merchant: Merchant }) {
  const router = useRouter();
  const [storeName, setStoreName] = useState(merchant.store_name);
  const [addressText, setAddressText] = useState(merchant.address_text ?? "");
  const [phone, setPhone] = useState(merchant.phone ?? "");
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ store_name: storeName, address_text: addressText, phone })
      .eq("id", merchant.id);

    if (error) {
      setError("تعذّر حفظ التعديلات.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setLoading(false);
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div>
        <label className="block text-sm font-medium mb-1">اسم المحل</label>
        <input
          type="text"
          required
          value={storeName}
          onChange={(e) => setStoreName(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          العنوان بالتفصيل
        </label>
        <input
          type="text"
          required
          value={addressText}
          onChange={(e) => setAddressText(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">هاتف المحل</label>
        <input
          type="tel"
          required
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      {error && <p className="text-error text-sm">{error}</p>}
      {saved && <p className="text-primary text-sm">تم الحفظ بنجاح.</p>}

      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-lg bg-primary text-white font-semibold py-3 mt-2 disabled:opacity-60"
      >
        {loading ? "جارٍ الحفظ..." : "حفظ التعديلات"}
      </button>
    </form>
  );
}
