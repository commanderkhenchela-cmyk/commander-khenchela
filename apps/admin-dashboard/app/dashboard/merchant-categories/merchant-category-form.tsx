"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function MerchantCategoryForm({
  nextSortOrder,
  services,
  parentOptions,
}: {
  nextSortOrder: number;
  services: { id: string; name: string }[];
  // تصنيفات أب مرشَّحة لتصنيف فرعي جديد (فقط تصنيفات جذر موجودة) — راجع
  // migration 20260824010000_service_categories: parent_id يُستخدم الآن
  // فعليًا لتصنيفات المطاعم الفرعية (بيتزا/مشاوي...) تحت "مطاعم".
  parentOptions: { id: string; name: string; serviceId: string }[];
}) {
  const router = useRouter();
  const [icon, setIcon] = useState("🛍️");
  const [name, setName] = useState("");
  const [serviceId, setServiceId] = useState(services[0]?.id ?? "");
  const [parentId, setParentId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // تصنيف فرعي يتبع نفس خدمة أبيه إجباريًا — لا معنى لتصنيف فرعي بخدمة
  // مختلفة عن أبيه، فنضبطها تلقائيًا بدل ترك تعارض ممكن.
  const availableParents = parentOptions.filter(
    (p) => p.serviceId === serviceId,
  );

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error } = await supabase.from("merchant_categories").insert({
      name,
      icon: icon.trim() || "🛍️",
      sort_order: nextSortOrder,
      service_id: serviceId,
      parent_id: parentId || null,
    });

    if (error) {
      setError("تعذّر إضافة التصنيف.");
      setLoading(false);
      return;
    }

    setName("");
    setIcon("🛍️");
    setParentId("");
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2">
      <div className="flex gap-2">
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
      </div>
      <div className="flex gap-2">
        <select
          value={serviceId}
          onChange={(e) => {
            setServiceId(e.target.value);
            setParentId("");
          }}
          className="flex-1 rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
        >
          {services.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
        <select
          value={parentId}
          onChange={(e) => setParentId(e.target.value)}
          className="flex-1 rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
        >
          <option value="">بدون أب (تصنيف رئيسي)</option>
          {availableParents.map((p) => (
            <option key={p.id} value={p.id}>
              فرعي تحت: {p.name}
            </option>
          ))}
        </select>
        <button
          type="submit"
          disabled={loading || !serviceId}
          className="rounded-lg bg-primary text-white font-semibold px-4 disabled:opacity-60"
        >
          إضافة
        </button>
      </div>
      {error && <p className="text-error text-sm">{error}</p>}
    </form>
  );
}
